local bootstrap = require("__test__.support.bootstrap")
local t = require("__test__.support.harness").new()
local fixture = require("__test__.support.filetree").new(t)
local filetree = fixture.filetree
local attach, await, write = fixture.attach, fixture.await, fixture.write

t:test("a reentrant source update cannot deliver an older revision after the newer one", function()
  local path = t:tempdir()
  local data = await(filetree.open(path))
  local nested, revisions = false, {}
  local first = data:subscribe({
    on_source_changed = function()
      if not nested then
        nested = true
        fixture.write(path .. "/second")
        await(data:resolve(path .. "/second"))
        vim.wait(10, function()
          return false
        end, 1)
      end
    end,
  })
  local second = data:subscribe({
    on_source_changed = function(revision)
      revisions[#revisions + 1] = revision
    end,
  })
  t:defer(function()
    first:unsubscribe()
    second:unsubscribe()
  end)
  fixture.write(path .. "/first")
  await(data:resolve(path .. "/first"))
  t.wait_until(function()
    return #revisions > 0
  end, 5000)
  t.assert_eq(data:source():revision(), revisions[#revisions], "latest source observation must not be rolled back")
end)

t:test("watch revisions reach subscribers and the original handler once through attach and detach", function()
  local received, wrapped = {}, {}
  local path = t:tempdir()
  write(path .. "/first")
  local data = await(filetree.open(path, {
    on_effect = function(effect)
      if effect.kind == "WatchStatus" then
        received[#received + 1] = effect.status
      end
    end,
  }))
  local state = await(data:create_state())
  received = {}
  local subscription = data:subscribe({
    on_effect = function(effect)
      if effect.kind == "WatchStatus" then
        wrapped[#wrapped + 1] = effect.status
      end
    end,
  })
  t:defer(function()
    subscription:unsubscribe()
  end)
  local view = attach(state, { keymaps = false })
  t.wait_until(function()
    return #wrapped > 0 and wrapped[#wrapped].directories > 0
  end, 10000)
  view:detach()
  t.wait_until(function()
    return wrapped[#wrapped].directories == 0
  end, 10000)
  t.assert_eq(#wrapped, #received)
  local revisions = {}
  for index, status in ipairs(wrapped) do
    t.assert_eq(status, received[index], "the original handler receives the same status")
    t.assert_false(revisions[status.revision] == true, "each watch revision is delivered once")
    revisions[status.revision] = true
  end
end)

-- An observer of either channel may unsubscribe itself and others and subscribe a new one while an event is delivered:
-- an observer it removes misses that event, and the new one receives only the events after it.
for _, case in ipairs({
  {
    name = "source observers can unsubscribe and register during delivery without replay",
    channel = "on_source_changed",
    ---Returns a function that changes the source: each call writes and resolves the next file.
    ---@param data                      ux.filetree.Data
    ---@param path                      string
    ---@return fun(): nil
    start = function(data, path)
      local names, count = { "first", "second", "third" }, 0
      return function()
        count = count + 1
        write(path .. "/" .. names[count])
        await(data:resolve(path .. "/" .. names[count]))
      end
    end,
    ---@param data                      ux.filetree.Data
    ---@param revision                  integer
    ---@return boolean
    delivered = function(data, revision)
      t.assert_eq(data:source():revision(), revision)
      return true
    end,
  },
  {
    name = "effect observers can change subscriptions without receiving an in-flight event twice",
    channel = "on_effect",
    ---Returns a function that emits a TaskFailed effect: a selection lock that cannot wait fails.
    ---@param data                      ux.filetree.Data
    ---@return fun(): nil
    start = function(data)
      local state = await(data:create_state())
      return function()
        await(state:lock_selection(0))
      end
    end,
    ---@param _                         ux.filetree.Data
    ---@param effect                    ux.filetree.IEffect
    ---@return boolean
    delivered = function(_, effect)
      return effect.kind == "TaskFailed"
    end,
  },
}) do
  t:test(case.name, function()
    local path = t:tempdir()
    local data = await(filetree.open(path))
    local deliver = case.start(data, path)
    local first, second, late, probe
    local calls = { first = 0, second = 0, late = 0, probe = 0 }
    t:defer(function()
      for _, subscription in pairs({ first = first, second = second, late = late, probe = probe }) do
        subscription:unsubscribe()
      end
    end)

    ---Subscribes to the events of the channel, counting each with `count`.
    ---@param count                     fun(): nil
    ---@return stl.c.IUnsubscribable
    local function observe(count)
      return data:subscribe({
        [case.channel] = function(value)
          if case.delivered(data, value) then
            count()
          end
        end,
      })
    end

    first = observe(function()
      calls.first = calls.first + 1
      first:unsubscribe()
      second:unsubscribe()
      late = observe(function()
        calls.late = calls.late + 1
      end)
    end)
    second = observe(function()
      calls.second = calls.second + 1
    end)
    deliver()
    t.wait_until(function()
      return calls.first == 1
    end, 10000)
    t.assert_eq(0, calls.second)
    t.assert_eq(0, calls.late, "a new observer starts after the event in flight")
    deliver()
    t.wait_until(function()
      return calls.late == 1
    end, 10000)
    late:unsubscribe()
    late:unsubscribe()
    -- An observer subscribed meanwhile shows when the next event has been delivered.
    probe = observe(function()
      calls.probe = calls.probe + 1
    end)
    deliver()
    t.wait_until(function()
      return calls.probe == 1
    end, 10000)
    t.assert_eq(1, calls.first)
    t.assert_eq(1, calls.late)
  end)
end

t:test("a reentrant view close cannot restore superseded watch coverage", function()
  local data = await(filetree.open(t:tempdir()))
  local state = await(data:create_state())
  local view, closed
  local received = {}
  local first = data:subscribe({
    on_effect = function(effect)
      if effect.kind == "WatchStatus" and effect.status.roots > 0 and not closed then
        closed = true
        view:detach()
        t.wait_until(function()
          return data:watch_status().roots == 0
        end, 5000)
        vim.wait(10, function()
          return false
        end, 1)
      end
    end,
  })
  local second = data:subscribe({
    on_effect = function(effect)
      if effect.kind == "WatchStatus" then
        received[#received + 1] = effect.status
      end
    end,
  })
  t:defer(function()
    first:unsubscribe()
    second:unsubscribe()
  end)
  view = fixture.attach(state, { keymaps = false })
  t.wait_until(function()
    return closed and #received > 0
  end, 5000)
  t.assert_eq(0, received[#received].roots)
end)

t:test("a failed subscriber cannot suppress later observers or the original handler", function()
  local reports, delivered = bootstrap.with_reporter(t), {}
  local data = await(filetree.open(t:tempdir(), {
    on_effect = function(effect)
      if effect.kind == "TaskFailed" then
        delivered[#delivered + 1] = "original"
      end
    end,
  }))
  local state = await(data:create_state())
  local failed = data:subscribe({
    on_effect = function(effect)
      if effect.kind == "TaskFailed" then
        error("subscriber failure", 0)
      end
    end,
  })
  local healthy = data:subscribe({
    on_effect = function(effect)
      if effect.kind == "TaskFailed" then
        delivered[#delivered + 1] = "subscriber"
      end
    end,
  })
  t:defer(function()
    failed:unsubscribe()
    healthy:unsubscribe()
  end)
  await(state:lock_selection(0))
  t.wait_until(function()
    return #delivered == 2
  end, 5000)
  t.assert_same({ "subscriber", "original" }, delivered)
  t.assert_eq(1, #reports.error)
  t.assert_eq("subscriber failure", reports.error[1].message)
end)

t:run()
