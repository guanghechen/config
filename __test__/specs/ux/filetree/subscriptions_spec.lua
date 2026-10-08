---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.specs.ux.filetree.subscriptions" ---@type string

local fixture = require("__test__.support.filetree").new("ux.filetree.subscriptions")
local t, filetree, await = fixture.t, fixture.filetree, fixture.await

t:test("a reentrant source update cannot deliver an older revision after the newer one", function()
  local path = fixture.directory()
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

t:test("effect observers can change subscriptions without receiving an in-flight event twice", function()
  local data = await(filetree.open(fixture.directory()))
  local state = await(data:create_state())
  local first, second, late
  local calls = { first = 0, second = 0, late = 0 }
  t:defer(function()
    for _, subscription in pairs({ first = first, second = second, late = late }) do
      subscription:unsubscribe()
    end
  end)
  first = data:subscribe({
    on_effect = function(effect)
      if effect.kind == "TaskFailed" then
        calls.first = calls.first + 1
        first:unsubscribe()
        second:unsubscribe()
        late = data:subscribe({
          on_effect = function(value)
            if value.kind == "TaskFailed" then
              calls.late = calls.late + 1
            end
          end,
        })
      end
    end,
  })
  second = data:subscribe({
    on_effect = function(effect)
      if effect.kind == "TaskFailed" then
        calls.second = calls.second + 1
      end
    end,
  })
  await(state:lock_selection(0))
  t.wait_until(function()
    return calls.first == 1
  end, 5000)
  t.assert_eq(0, calls.second)
  t.assert_eq(0, calls.late)
  await(state:lock_selection(0))
  t.wait_until(function()
    return calls.late == 1
  end, 5000)
  t.assert_eq(1, calls.first)
end)

t:test("a reentrant view close cannot restore superseded watch coverage", function()
  local data = await(filetree.open(fixture.directory()))
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
    view:detach()
    first:unsubscribe()
    second:unsubscribe()
  end)
  view = filetree.attach(state, { keymaps = false })
  t.wait_until(function()
    return closed and #received > 0
  end, 5000)
  t.assert_eq(0, received[#received].roots)
end)

t:test("a failed subscriber cannot suppress later observers or the original handler", function()
  local reports, delivered = {}, {}
  t:patch_table(stl.reporter, "error", function(value)
    reports[#reports + 1] = value.message
  end)
  local data = await(filetree.open(fixture.directory(), {
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
  t.assert_true(vim.deep_equal({ "subscriber", "original" }, delivered))
  t.assert_true(vim.deep_equal({ "subscriber failure" }, reports))
end)

t:run()
