---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.specs.era.m.explorer.preparation" ---@type string

local fixture = require("__test__.support.explorer").new("era.m.explorer.preparation")
local t, await = fixture.t, fixture.await
local Session = require("era.m.explorer.session")
local jobs = require("era.m.explorer.jobs")

---@return era.m.explorer.Widget, string
local function setup()
  local path = fixture.directory()
  fixture.write(path .. "/a")
  assert(vim.uv.fs_mkdir(path .. "/branch", 448))
  local widget = fixture.widget(path)
  fixture.cursor(widget, path .. "/a")
  return widget, path
end

t:test("direct transfers keep their captured source after unrelated browse materialization", function()
  for _, kind in ipairs({ "copy", "cut" }) do
    local widget, path = setup()
    local session, view = widget:context()
    local frame = view:frame()
    fixture.write(path .. "/branch/new")
    await(session.data:resolve(path .. "/branch/new"))
    t.assert_true(frame:header().selection_revision ~= session.state:status().revisions.selection)
    t:patch_table(vim.ui, "input", function(options, done)
      t.assert_true(options.prompt == "Copy to: " or options.prompt == "Move to: ")
      done(path .. "/transferred")
    end)
    local restore = t:patch_table(view, "frame", function()
      return frame
    end)
    local future = widget._action:transfer(kind)
    restore()
    await(future)
    fixture.idle(widget)
    t.assert_true(vim.uv.fs_stat(path .. "/transferred") ~= nil)
    t.assert_eq(kind == "copy", vim.uv.fs_stat(path .. "/a") ~= nil)
    t.assert_eq(1, session._counts.success)
  end
end)

t:test("read-only selection uses one snapshot across unrelated source updates", function()
  local widget, path = setup()
  local session = widget._session
  await(widget._action:mark("copy"))
  fixture.idle(widget)
  fixture.write(path .. "/branch/new")
  local changed = false
  local wait = Session.await
  t:patch_table(Session, "await", function(future)
    local value = wait(future)
    if not changed and type(value) == "table" and (value.kind == "Inspected" or value.kind == "Ready") then
      changed = true
      wait(session.data:resolve(path .. "/branch/new"))
      t.assert_true(value.revisions.data ~= session.data:source():revision())
    end
    return value
  end)
  local captured
  t:patch_table(era.fn, "select_copy_filepaths", function(options)
    captured = options.filepaths
  end)
  await(widget._action:auxiliary("copy_path"))
  t.assert_true(changed)
  t.assert_true(vim.deep_equal({ path .. "/a" }, captured), vim.inspect(captured))
  t.assert_false(session:busy())
end)

t:test("direct transfers reject selection changes even after the selection becomes empty again", function()
  local widget, path = setup()
  local session, view = widget:context()
  local frame = view:frame()
  await(widget._action:mark("copy"))
  await(session.state:clear_selection())
  local prompted = false
  t:patch_table(vim.ui, "input", function()
    prompted = true
  end)
  local restore = t:patch_table(view, "frame", function()
    return frame
  end)
  local future = widget._action:transfer("cut")
  restore()
  t.wait_until(function()
    return future:is_done()
  end, 10000)
  t.assert_true(future:is_failed())
  t.assert_true(future:get_error():find("selection intent changed", 1, true) ~= nil)
  t.assert_false(prompted or session:busy() or jobs.pending())
  t.assert_true(vim.uv.fs_stat(path .. "/a") ~= nil)
end)

t:test("complete read-only selection coexists with an active job", function()
  local widget, path = setup()
  local session, view = widget:context()
  fixture.write(path .. "/branch/a")
  local target = await(session.data:resolve(path .. "/branch"))
  await(widget._action:mark("copy"))
  local confirming = false
  t:patch_table(vim.ui, "input", function()
    confirming = true
  end)
  local job = await(session:operate(view, { kind = "paste", target = target }))
  t.wait_until(function()
    return confirming
  end, 10000)
  local captured
  t:patch_table(era.fn, "select_copy_filepaths", function(options)
    captured = options.filepaths
  end)
  await(widget._action:auxiliary("copy_path"))
  t.assert_true(vim.deep_equal({ path .. "/a" }, captured))
  t.assert_true(session.job == job)
  t.assert_nil(session._preparation)
  t.assert_true(session.state:status().locked)
  jobs.cancel(session)
  fixture.idle(widget)
end)

t:test("cancelling a complete inspection discards its late snapshot without a task", function()
  local widget = setup()
  local session = widget._session
  await(widget._action:mark("copy"))
  local pending, resolve = stl.c.Future.new_with_resolver()
  local waiting = false
  local wait = Session.await
  t:patch_table(Session, "await", function(future)
    local reply = wait(future)
    if type(reply) == "table" and reply.kind == "Inspected" and not waiting then
      waiting = true
      wait(pending)
    end
    return reply
  end)
  local captured
  t:patch_table(era.fn, "select_copy_filepaths", function(options)
    captured = options.filepaths
  end)
  local future = widget._action:auxiliary("copy_path")
  t.wait_until(function()
    return waiting
  end, 10000)
  t.assert_false(session.state:status().locked)
  jobs.cancel(session)
  resolve(true)
  await(future)
  t.assert_nil(captured)
  t.assert_false(session:busy() or jobs.pending())
end)

t:run()
