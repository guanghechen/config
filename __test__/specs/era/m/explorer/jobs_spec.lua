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

t:run()
