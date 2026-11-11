local t = require("__test__.support.harness").new()
local fixture = require("__test__.support.explorer").new(t)
local await = fixture.await

t:test("completion and confirmation release selection without a recurring progress timer", function()
  local path = t:tempdir()
  local widget = fixture.widget(path)
  local session, view = widget:context()
  local timers, completed = 0, 0
  -- The Pending poll of source preparation is the only timer jobs.lua may arm. Count, without holding them, the
  -- timers it arms at any other time, of any delay: they would observe a Job.
  for _, target in ipairs({ { vim, "defer_fn" }, { vim.uv, "new_timer" } }) do
    local create = target[1][target[2]]
    t:patch_table(target[1], target[2], function(...)
      if not session.preparing and debug.getinfo(2, "S").source:find("era/m/explorer/jobs.lua", 1, true) then
        timers = timers + 1
      end
      return create(...)
    end)
  end

  for _, name in ipairs({ "first", "second" }) do
    local job = await(session:operate(view, {
      kind = "create",
      path = name,
      on_complete = function(status)
        t.assert_eq(nil, status.error)
        t.assert_false(session.state:status().locked)
        completed = completed + 1
      end,
    }))
    t.wait_until(function()
      return job:status().terminal
    end, 10000)
    t.wait_until(function()
      return session.job == nil
    end, 10000, "completed IO must release the Job")
    t.assert_true(vim.uv.fs_stat(path .. "/" .. name) ~= nil)
  end
  fixture.cursor(widget, path .. "/first")
  local confirmations = 0
  t:patch_table(vim.ui, "input", function(options, done)
    t.assert_eq("confirmation", options.inputtype)
    confirmations = confirmations + 1
    done("")
  end)
  local copy = await(session:operate(view, { kind = "copy_to_path", path = path .. "/second" }))
  t.wait_until(function()
    return session.job == nil
  end, 10000, "a new conflict and its terminal result must release the Job")
  t.assert_eq(1, confirmations)
  t.assert_eq("skipped", copy:results(1, 1)[1].status)
  -- A recurring timer would arm again within this window.
  vim.wait(200)
  t.assert_eq(0, timers, "Job observation must not create a recurring progress timer")
  t.assert_eq(2, completed)
  t.assert_false(require("era.m.explorer.jobs").pending())
end)

t:test("cancelling preparation settles before a late prompt and permits a new operation", function()
  local path = t:tempdir()
  local widget = fixture.widget(path)
  local session, view = widget:context()
  local answered
  t:patch_table(vim.ui, "input", function(_, done)
    answered = done
  end)
  local preparing = session:operate(view, { kind = "create" })
  t.wait_until(function()
    return answered ~= nil
  end, 10000)
  require("era.m.explorer.jobs").cancel(session)
  await(preparing)
  fixture.idle(widget)
  t.assert_false(require("era.m.explorer.jobs").pending())
  await(session:operate(view, { kind = "create", path = "accepted" }))
  answered("late")
  fixture.idle(widget)
  t.assert_true(vim.uv.fs_stat(path .. "/accepted") ~= nil)
  t.assert_eq(nil, vim.uv.fs_stat(path .. "/late"))
  local again = session:operate(view, { kind = "create" })
  t.wait_until(function()
    return session.preparing and session._preparation.resume ~= nil
  end, 10000)
  widget:dispose()
  await(again)
  t.assert_eq(nil, session.native)
  t.assert_eq(nil, session.data)
end)

t:run()
