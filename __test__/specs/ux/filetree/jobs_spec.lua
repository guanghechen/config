---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.specs.ux.filetree.jobs" ---@type string

local fixture = require("__test__.support.filetree").new("ux.filetree.jobs")
local t, filetree = fixture.t, fixture.filetree
local await, write, directory = fixture.await, fixture.write, fixture.directory

t:test("an unchanged running Job sleeps and notification failure preserves completion", function()
  local data = await(filetree.open(directory()))
  local owner, calls, observed = data._tree, 0, nil
  local status = {
    revision = "1",
    terminal = false,
    cancelling = false,
    cancelled = false,
    results = 0,
    processed = 0,
    bytes = 0,
    phase = "working",
  }
  local job = {
    status = function(_, previous)
      calls = calls + 1
      if previous == status.revision then
        return nil
      end
      return vim.tbl_extend("force", {}, status)
    end,
  }
  data:_track_job(job, function(value)
    observed = value
  end)
  t.wait_until(function()
    return observed ~= nil and not data._native:is_busy()
  end, 5000)
  local previous, settled = calls, vim.uv.hrtime()
  t.wait_until(function()
    if previous ~= calls then
      previous, settled = calls, vim.uv.hrtime()
    end
    return vim.uv.hrtime() - settled >= 100000000
  end, 2000, "a running Job without changes must stop status polling")
  local errors = {}
  t:patch_table(stl.reporter, "error", function(value)
    errors[#errors + 1] = value.message
  end)
  owner._notification.subscription:close()
  t.wait_until(function()
    return owner._notification_failed
  end, 5000)
  status.terminal = true
  status.revision = "2"
  t.wait_until(function()
    return observed.terminal
  end, 5000, "fallback polling must deliver completion after the notification stream fails")
  t.assert_eq(1, #errors)
  t.assert_eq(nil, next(data._jobs))
end)

t:test("a hidden Job delivers confirmation and cancellation through native notifications", function()
  local path = directory()
  assert(vim.uv.fs_mkdir(path .. "/dst", 448))
  write(path .. "/source")
  write(path .. "/dst/source")
  local data = await(filetree.open(path))
  local source = await(data:resolve(path .. "/source"))
  local target = await(data:resolve(path .. "/dst"))
  local job =
    data:start_operation({ kind = "copy", source = source:source(), nodes = { source:node() }, target = target })
  t:defer(function()
    job:cancel()
  end)
  local observed
  data:_track_job(job, function(status)
    observed = status
  end)
  t.wait_until(function()
    return observed and observed.confirmation
  end, 5000, "the confirmation must arrive without an attached view")
  t.assert_false(observed.terminal)
  job:cancel()
  t.wait_until(function()
    return observed.terminal and data._tree._notification == nil
  end, 5000, "terminal delivery must also release the hidden data's notification lease")
  t.assert_true(observed.cancelled)
  t.assert_eq(nil, next(data._jobs))
  t.assert_true(vim.uv.fs_stat(path .. "/source") ~= nil)
end)

t:test("registration observes already finished Jobs and failures without a source publication", function()
  local path = directory()
  assert(vim.uv.fs_mkdir(path .. "/target", 448))
  local data = await(filetree.open(path))
  local target = await(data:resolve(path .. "/target"))
  local first = data._native:start_create({ target = target, path = "first", directory = false })
  local deadline = vim.uv.hrtime() + 5000000000
  while not first:status().terminal and vim.uv.hrtime() < deadline do
    vim.uv.sleep(1)
  end
  t.assert_true(first:status().terminal)
  local completed, failure = 0, nil
  data:_track_job(first, function(status)
    t.assert_true(status.terminal)
    t.assert_eq(nil, status.error)
    completed = completed + 1
  end)
  t.wait_until(function()
    return completed == 1 and data._tree._notification == nil
  end, 5000)
  assert(vim.uv.fs_rename(path .. "/target", path .. "/moved"))
  local second = data._native:start_create({ target = target, path = "second", directory = false })
  data:_track_job(second, function(status)
    if status.terminal then
      failure = status.error
    end
  end)
  t.wait_until(function()
    return failure ~= nil and data._tree._notification == nil
  end, 5000, "a failed Job must wake Lua even when no filesystem change was published")
  t.assert_eq(1, completed)
  t.assert_eq(nil, vim.uv.fs_stat(path .. "/moved/second"))
end)

t:test("native Job confirms one conflict and consumes opaque prepared NodeIds", function()
  local path = directory()
  assert(vim.uv.fs_mkdir(path .. "/dst", 448))
  write(path .. "/source")
  write(path .. "/dst/source")
  local data = await(filetree.open(path))
  local source = await(data:resolve(path .. "/source"))
  local target = await(data:resolve(path .. "/dst"))
  local state = await(data:create_state())
  await(state:select_node({ source:node() }, true))
  local task = await(state:lock_selection())
  local ready = await(task:prepare_sources())
  t.assert_eq("Ready", ready.kind)
  local job = data:start_operation({
    kind = "copy",
    source = ready.source,
    nodes = ready.subtree_roots,
    target = target,
    task = { state = state, lock = task.token, cleanup = ready.cleanup },
  })
  t:defer(function()
    job:cancel()
  end)
  t.wait_until(function()
    return job:status().confirmation ~= nil
  end, 10000)
  local waiting = job:status()
  t.assert_eq("string", type(waiting.revision))
  t.assert_eq(nil, job:status(waiting.revision))
  local confirmation = waiting.confirmation
  t.assert_eq(path .. "/dst/source", confirmation.target)
  job:confirm(confirmation.token, true)
  t.wait_until(function()
    return job:status().terminal
  end, 10000)
  local status = job:status()
  t.assert_true(job:status(waiting.revision) ~= nil)
  t.assert_eq(nil, status.error)
  t.assert_eq("success", status.cleanup)
  t.assert_false(state:status().locked)
  local result = job:results(1, status.results)
  t.assert_eq("success", result[1].status)
  t.assert_eq(nil, result[1].sync_error)
  t.assert_eq(source:node(), result[1].node)
end)

t:test("Job finishes multiple pages after the Lua data facade is collected", function()
  local path = directory()
  assert(vim.uv.fs_mkdir(path .. "/src", 448))
  assert(vim.uv.fs_mkdir(path .. "/dst", 448))
  for i = 1, 600 do
    write(path .. "/src/file-" .. i)
  end
  local data = await(filetree.open(path))
  local source = await(data:resolve(path .. "/src"))
  local target = await(data:resolve(path .. "/dst"))
  local job =
    data:start_operation({ kind = "copy", source = source:source(), nodes = { source:node() }, target = target })
  t:defer(function()
    job:cancel()
  end)
  data, source, target = nil, nil, nil
  collectgarbage("collect")
  t.wait_until(function()
    return job:status().terminal
  end, 15000)
  t.assert_eq(nil, job:status().error)
  local results = job:results(1, job:status().results)
  t.assert_eq("success", results[1].status)
  t.assert_eq(nil, results[1].sync_error)
  t.assert_true(vim.uv.fs_stat(path .. "/dst/src/file-600") ~= nil)
end)

t:test("a prepared complete directory survives unchanged paged refresh before IO", function()
  local path = directory()
  assert(vim.uv.fs_mkdir(path .. "/src", 448))
  assert(vim.uv.fs_mkdir(path .. "/dst", 448))
  for index = 1, 600 do
    write(path .. "/src/file-" .. index)
  end
  local data = await(filetree.open(path))
  local source = await(data:resolve(path .. "/src"))
  local target = await(data:resolve(path .. "/dst"))
  local state = await(data:create_state())
  local view = filetree.attach(state, { keymaps = false })
  t:defer(function()
    view:detach()
  end)
  await(state:set_expanded({ source:node() }, true, false))
  t.wait_until(function()
    return data._native:is_settled() and data:source():node(source:node()).completeness == "complete"
  end, 10000)
  await(state:select_node({ source:node() }, true))
  local task = await(state:lock_selection())
  local ready = await(task:prepare_sources())
  t.assert_eq("Ready", ready.kind)
  await(data:refresh(state))
  t.wait_until(function()
    return data._native:is_settled()
  end, 10000)
  local job = data:start_operation({
    kind = "copy",
    source = ready.source,
    nodes = ready.subtree_roots,
    target = target,
    task = { state = state, lock = task.token, cleanup = ready.cleanup },
  })
  t:defer(function()
    job:cancel()
  end)
  t.wait_until(function()
    return job:status().terminal
  end, 15000)
  t.assert_eq(nil, job:status().error)
  t.assert_eq("success", job:status().cleanup)
  t.assert_false(state:status().locked)
  for index = 1, 600 do
    t.assert_true(vim.uv.fs_stat(path .. "/src/file-" .. index) ~= nil)
    t.assert_true(vim.uv.fs_stat(path .. "/dst/src/file-" .. index) ~= nil)
  end
end)

t:test("private descendants expose stable Job item IDs without requiring browse nodes", function()
  local path = directory()
  assert(vim.uv.fs_mkdir(path .. "/src", 448))
  assert(vim.uv.fs_mkdir(path .. "/dst", 448))
  assert(vim.uv.fs_mkdir(path .. "/dst/src", 448))
  write(path .. "/src/copied")
  write(path .. "/src/skipped")
  write(path .. "/dst/src/skipped")
  local data = await(filetree.open(path))
  local source = await(data:resolve(path .. "/src"))
  local target = await(data:resolve(path .. "/dst"))
  t.assert_eq(0, data:source():node(source:node()).child_count)
  local state = await(data:create_state())
  await(state:select_node({ source:node() }, true))
  local task = await(state:lock_selection())
  local ready = await(task:prepare_sources())
  local job = data:start_operation({
    kind = "copy",
    source = ready.source,
    nodes = ready.subtree_roots,
    target = target,
    task = { state = state, lock = task.token, cleanup = ready.cleanup },
  })
  t:defer(function()
    job:cancel()
  end)
  t.wait_until(function()
    return job:status().confirmation ~= nil
  end, 10000)
  local confirmation = job:status().confirmation
  t.assert_true(confirmation.item:match("^i%d+$") ~= nil)
  t.assert_eq(nil, confirmation.node)
  t.assert_eq(path .. "/src/skipped", confirmation.source)
  job:confirm(confirmation.token, false)
  t.wait_until(function()
    return job:status().terminal
  end, 10000)
  local status = job:status()
  t.assert_eq(nil, status.error)
  t.assert_eq("success", status.cleanup)
  t.assert_false(state:status().locked)
  local ids, copied = {}, nil
  for _, result in ipairs(job:results(1, status.results)) do
    t.assert_true(result.item:match("^i%d+$") ~= nil)
    t.assert_eq(nil, ids[result.item])
    ids[result.item] = true
    if result.source == path .. "/src/copied" then
      copied = result
      t.assert_eq("success", result.status)
      t.assert_eq(nil, result.node)
    elseif result.source == path .. "/src/skipped" then
      t.assert_eq("skipped", result.status)
      t.assert_eq(confirmation.item, result.item)
      t.assert_eq(nil, result.node)
    end
  end
  t.assert_true(copied ~= nil)
  t.assert_eq(1, data:source():node(source:node()).child_count)
  local admitted = await(data:resolve(path .. "/src/copied"))
  t.assert_true(admitted:node() ~= nil)
  for _, result in ipairs(job:results(1, status.results)) do
    if result.item == copied.item then
      t.assert_eq(copied.source, result.source)
      t.assert_eq(nil, result.node, "cleanup admission must not rewrite historical records")
    end
  end
end)

t:test("terminal Job after the event drain still delivers the final RootUnavailable effect", function()
  local path = directory()
  assert(vim.uv.fs_mkdir(path .. "/branch", 448))
  local received = false
  local data = await(filetree.open(path, {
    on_effect = function(effect)
      received = received or effect.kind == "RootUnavailable"
    end,
  }))
  local branch = await(data:resolve(path .. "/branch"))
  local state = await(data:create_state({ kind = "children_of", node = branch:node() }))
  local owner, job = data._tree, nil
  vim.wait(50, function()
    return false
  end, 50)
  local native = owner._native
  t:patch_table(
    owner,
    "_native",
    setmetatable({
      events = function()
        local drained = native:events()
        if not job then
          job = data:start_operation({ kind = "delete", source = branch:source(), nodes = { branch:node() } })
          local deadline = vim.uv.hrtime() + 5000000000
          while not job:status().terminal and vim.uv.hrtime() < deadline do
            vim.uv.sleep(1)
          end
          t.assert_true(job:status().terminal, "background Job must complete without running Lua callbacks")
          t.assert_false(received, "the final event is deliberately after this drain")
        end
        return drained
      end,
    }, {
      __index = function(_, key)
        return function(_, ...)
          return native[key](native, ...)
        end
      end,
    })
  )
  t:defer(function()
    if job then
      job:cancel()
    end
  end)
  require("ux.treeview.async").watch(owner)
  t.wait_until(function()
    return received
  end, 500, "final native effects must not wait for a future user action")
  t.assert_eq(nil, vim.uv.fs_stat(path .. "/branch"))
  t.assert_true(state:snapshot():header().row_count == 0)
end)

t:run()
