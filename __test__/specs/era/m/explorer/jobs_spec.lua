---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.specs.era.m.explorer.jobs" ---@type string

local fixture = require("__test__.support.explorer").new("era.m.explorer.jobs")
local t, await, write, directory = fixture.t, fixture.await, fixture.write, fixture.directory

t:test("a hidden Job drains its complete result backlog before releasing the session", function()
  local path = directory()
  assert(vim.uv.fs_mkdir(path .. "/dst", 448))
  for index = 1, 260 do
    write(string.format("%s/file-%03d", path, index))
  end
  local widget = fixture.widget(path)
  local session, view = widget:context()
  local nodes = {}
  for index = 1, 260 do
    nodes[index] = await(session.data:resolve(string.format("%s/file-%03d", path, index))):node()
  end
  await(session.state:select_node(nodes, true))
  local target = await(session.data:resolve(path .. "/dst"))
  local completed, delivered = 0, 0
  local buffers = require("era.m.explorer.buffers")
  local sync = buffers.sync
  t:patch_table(buffers, "sync", function(...)
    delivered = delivered + 1
    return sync(...)
  end)
  local job = await(session:operate(view, {
    kind = "copy",
    target = target,
    on_complete = function(status)
      t.assert_eq(260, status.results)
      t.assert_eq(260, delivered)
      completed = completed + 1
    end,
  }))
  widget:hide()
  t.wait_until(function()
    return next(widget._views) == nil
  end, 5000)
  -- Hold Lua while native IO completes, leaving more than one result page to deliver.
  local deadline = vim.uv.hrtime() + 10000000000
  while not job:status().terminal and vim.uv.hrtime() < deadline do
    vim.uv.sleep(1)
  end
  t.assert_true(job:status().terminal)
  t.wait_until(function()
    return completed == 1 and session.job == nil
  end, 5000)
  t.assert_eq(260, session._counts.success)
  t.assert_eq(128, #session.results)
  t.assert_false(session.state:status().locked)
  t.assert_false(require("era.m.explorer.jobs").pending())
  t.assert_true(vim.uv.fs_stat(path .. "/dst/file-260") ~= nil)
end)

t:test("early failures and skips survive the successful tail and remain available from Last results", function()
  local path = directory()
  assert(vim.uv.fs_mkdir(path .. "/dst", 448))
  assert(vim.uv.fs_mkdir(path .. "/next", 448))
  assert(vim.uv.fs_mkdir(path .. "/dst/file-001", 448))
  write(path .. "/dst/file-002")
  for index = 1, 140 do
    write(string.format("%s/file-%03d", path, index))
  end
  local widget = fixture.widget(path)
  local session, view = widget:context()
  local nodes = {}
  for index = 1, 140 do
    nodes[index] = await(session.data:resolve(string.format("%s/file-%03d", path, index))):node()
  end
  await(session.state:select_node(nodes, true))
  t:patch_table(vim.ui, "input", function(_, done)
    done("n")
  end)
  await(session:operate(view, { kind = "copy", target = await(session.data:resolve(path .. "/dst")) }))
  fixture.idle(widget)
  t.assert_eq(138, session._counts.success)
  t.assert_eq(1, session._counts.failed)
  t.assert_eq(1, session._counts.skipped)
  t.assert_eq(128, #session.results)
  t.assert_eq(2, #session.issues)
  t.assert_eq(path .. "/file-001", session.issues[1].source)
  t.assert_eq("failed", session.issues[1].status)
  t.assert_eq(path .. "/file-002", session.issues[2].source)
  t.assert_eq("skipped", session.issues[2].status)
  t.assert_eq(0, session.issues_omitted)
  local message
  t:patch_table(stl.reporter, "info", function(value)
    message = value.message
  end)
  t:patch_table(vim.ui, "select", function(_, _, done)
    done("Last results")
  end)
  widget._action:menu()
  t.assert_true(message:find("file-001", 1, true) ~= nil)
  t.assert_true(message:find(session.issues[1].error.message, 1, true) ~= nil)
  t.assert_nil(session.job)

  await(session.state:clear_selection())
  await(session.state:select_node({ nodes[140] }, true))
  await(session:operate(view, { kind = "copy", target = await(session.data:resolve(path .. "/next")) }))
  fixture.idle(widget)
  t.assert_eq(0, #session.issues)
  t.assert_eq(0, session.issues_omitted)
  t.assert_eq(0, session._issue_bytes)
end)

for _, deep in ipairs({ false, true }) do
  t:test("issue history reports omissions at the " .. (deep and "byte" or "item") .. " limit", function()
    local path = directory()
    if deep then
      for _ = 1, 3 do
        path = path .. "/" .. string.rep("d", 180)
        assert(vim.uv.fs_mkdir(path, 448))
      end
    end
    assert(vim.uv.fs_mkdir(path .. "/dst", 448))
    for index = 1, 520 do
      write(string.format("%s/file-%03d", path, index))
      assert(vim.uv.fs_mkdir(string.format("%s/dst/file-%03d", path, index), 448))
    end
    local widget = fixture.widget(path)
    local session, view = widget:context()
    local nodes = {}
    for index = 1, 520 do
      nodes[index] = await(session.data:resolve(string.format("%s/file-%03d", path, index))):node()
    end
    await(session.state:select_node(nodes, true))
    local target = await(session.data:resolve(path .. "/dst"))
    -- Keep the history-limit fixture independent of watcher/task invalidation.
    widget:hide()
    t.wait_until(function()
      return session.data:watch_status().roots == 0 and not session.data._native:is_busy()
    end, 10000)
    await(session:operate(view, { kind = "copy", target = target }))
    fixture.idle(widget)
    t.assert_eq(520, session._counts.failed)
    t.assert_eq(520, #session.issues + session.issues_omitted)
    t.assert_true(session._issue_bytes <= 1024 * 1024)
    if deep then
      t.assert_true(#session.issues < 512)
    else
      t.assert_eq(512, #session.issues)
    end
    local message
    t:patch_table(stl.reporter, "info", function(value)
      message = value.message
    end)
    t:patch_table(vim.ui, "select", function(_, _, done)
      done("Last results")
    end)
    widget:focus()
    fixture.idle(widget)
    widget._action:menu()
    t.assert_true(message:find(session.issues_omitted .. " additional issues omitted", 1, true) ~= nil)
  end)
end

t:run()
