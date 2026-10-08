---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.specs.era.m.explorer.transfer" ---@type string

local fixture = require("__test__.support.explorer").new("era.m.explorer.transfer")
local t, await = fixture.t, fixture.await
local Future = require("stl.c.future")

---@param widget                        era.m.explorer.Widget
---@param target                        string
---@return nil
local function followed(widget, target)
  t.wait_until(function()
    return widget:get_cursor_filepath() == target
  end, 10000, "successful transfer must follow its destination")
  fixture.idle(widget)
end

---@param view                          ux.filetree.View
---@return integer
local function watches(view)
  return #vim.api.nvim_get_autocmds({ buf = view.bufnr, event = { "WinLeave", "BufLeave", "BufUnload" } })
end

for _, case in ipairs({
  { mark = "copy", outside = false },
  { mark = "cut", outside = true },
  { mark = "copy", outside = true },
}) do
  local mark = case.mark
  t:test(mark .. " follows its target with outside root " .. tostring(case.outside), function()
    local path = fixture.directory()
    fixture.write(path .. "/source.txt")
    fixture.write(path .. "/remaining.txt")
    local destination = case.outside and fixture.directory() or path
    local target = destination .. "/target.txt"
    local widget = fixture.widget(path)
    local _, view = widget:context()
    fixture.cursor(widget, path .. "/source.txt")
    local before = watches(view)
    t:patch_table(vim.ui, "input", function(_, done)
      done(target)
    end)
    await(widget._action:transfer(mark))
    followed(widget, target)
    t.assert_eq(destination, widget:get_root_filepath())
    t.assert_true(vim.uv.fs_stat(target) ~= nil)
    t.assert_eq(mark == "copy", vim.uv.fs_stat(path .. "/source.txt") ~= nil)
    t.assert_eq(before, watches(view))
  end)
end

t:test("a copied directory follows its root after more than 128 descendant results", function()
  local path = fixture.directory()
  assert(vim.uv.fs_mkdir(path .. "/source", 448))
  for index = 1, 140 do
    fixture.write(string.format("%s/source/file-%03d", path, index))
  end
  local widget = fixture.widget(path)
  local session = widget:context()
  fixture.cursor(widget, path .. "/source")
  await(widget._action:operate({ kind = "copy_to_path", path = path .. "/copied" }))
  followed(widget, path .. "/copied")
  t.assert_eq(path .. "/copied", session.results[#session.results].target)
  for index = 1, 140 do
    t.assert_true(vim.uv.fs_stat(string.format("%s/copied/file-%03d", path, index)) ~= nil)
  end
end)

t:test("Space path actions follow a single selected source and expand a nested target", function()
  for _, choice in ipairs({ "Copy to path", "Move to path" }) do
    local path = fixture.directory()
    fixture.write(path .. "/source")
    fixture.write(path .. "/other")
    local widget = fixture.widget(path)
    fixture.cursor(widget, path .. "/source")
    await(widget._action:mark("select"))
    fixture.cursor(widget, path .. "/other")
    t:patch_table(vim.ui, "select", function(_, _, done)
      done(choice)
    end)
    t:patch_table(vim.ui, "input", function(_, done)
      done(path .. "/nested/target")
    end)
    widget._action:menu()
    followed(widget, path .. "/nested/target")
    t.assert_true(vim.uv.fs_stat(path .. "/other") ~= nil)
    t.assert_eq(path, widget:get_root_filepath())
    widget:dispose()
  end
end)

for _, intent in ipairs({ "cursor", "root", "focus" }) do
  t:test("later " .. intent .. " intent during a path prompt revokes following even after returning", function()
    local path, other = fixture.directory(), fixture.directory()
    fixture.write(path .. "/source")
    fixture.write(path .. "/other")
    fixture.write(other .. "/file")
    local source_winnr = vim.api.nvim_get_current_win()
    local widget = fixture.widget(path)
    local session, view = widget:context()
    fixture.cursor(widget, path .. "/source")
    fixture.idle(widget)
    local before, answer = watches(view), nil
    t:patch_table(vim.ui, "input", function(_, done)
      answer = done
    end)
    local operation = widget._action:transfer("copy")
    t.wait_until(function()
      return answer ~= nil
    end, 10000)
    if intent == "cursor" then
      fixture.cursor(widget, path .. "/other")
      fixture.cursor(widget, path .. "/source")
    elseif intent == "root" then
      await(widget:set_root(other))
      await(widget:set_root(path))
      fixture.cursor(widget, path .. "/source")
    else
      vim.api.nvim_set_current_win(source_winnr)
      vim.api.nvim_set_current_win(view.winnr)
    end
    answer(path .. "/copied")
    await(operation)
    fixture.idle(widget)
    t.assert_true(vim.uv.fs_stat(path .. "/copied") ~= nil)
    t.assert_eq(path .. "/source", widget:get_cursor_filepath())
    t.assert_eq(path, widget:get_root_filepath())
    t.assert_eq(before, watches(view))
    t.assert_eq(0, session._counts.failed)
  end)
end

for _, intent in ipairs({
  "cursor",
  "pending_cursor",
  "shared",
  "display",
  "widget_display",
  "widget_display_aba",
  "flag_observable",
  "display_ack",
  "disabled_compress",
  "fold",
  "native_fold",
  "focus",
  "root",
  "job",
  "close",
  "dispose",
}) do
  local follows = intent == "display_ack" or intent == "disabled_compress"
  local name = follows and "ignored " .. intent .. " preserves transfer following"
    or "destination resolution cannot override later " .. intent .. " intent"
  t:test(name, function()
    local path = fixture.directory()
    fixture.write(path .. "/source")
    fixture.write(path .. "/other")
    if intent == "native_fold" then
      assert(vim.uv.fs_mkdir(path .. "/directory", 448))
      fixture.write(path .. "/directory/file")
    end
    local source_winnr = vim.api.nvim_get_current_win()
    local options = intent == "disabled_compress"
        and { o_flag_viewtype = require("stl.c.observable").from_value("list") }
      or nil
    local widget = fixture.widget(path, options)
    local session, view = widget:context()
    if intent == "display_ack" then
      widget:toggle_flag(4)
      widget:toggle_flag(4)
      t.wait_until(function()
        return not widget._display_scheduled
      end, 10000)
    end
    local shared
    if intent == "shared" then
      local sibling = fixture.widget(path, { session = session })
      local _, sibling_view = sibling:context()
      shared = sibling_view
      widget:focus()
    end
    fixture.cursor(widget, path .. "/source")
    local target = path .. "/copied"
    local data, resolve = session.data, session.data.resolve
    local waiting, release = Future.new_with_resolver()
    local captured, navigation
    t:patch_table(data, "resolve", function(self, requested)
      local pending = resolve(self, requested)
      if requested ~= target then
        return pending
      end
      return pending:then_(function(resource)
        captured = resource
        return waiting
      end)
    end)
    local navigate_path = session.navigate_path
    t:patch_table(session, "navigate_path", function(self, requested, reveal, valid)
      local pending = navigate_path(self, requested, reveal, valid)
      if requested == target then
        navigation = pending
      end
      return pending
    end)
    await(widget._action:operate({ kind = "copy_to_path", path = target }))
    t.wait_until(function()
      return captured ~= nil
    end, 10000)
    fixture.idle(widget)
    local expected = path .. "/source"
    if intent == "cursor" then
      fixture.cursor(widget, path .. "/other")
      fixture.cursor(widget, expected)
    elseif intent == "pending_cursor" then
      local resource = await(data:resolve(path .. "/other"))
      vim.api.nvim_win_set_cursor(view.winnr, { view:frame():position(resource:node()), 0 })
      expected = path .. "/other"
    elseif intent == "shared" then
      for _, name in ipairs({ "other", "source" }) do
        local resource = await(data:resolve(path .. "/" .. name))
        await(shared:set_cursor(shared:frame():position(resource:node())))
      end
    elseif intent == "display" then
      local display = session.state:display()
      await(session.state:set_display(vim.tbl_extend("force", display, { mode = "list" })))
      await(session.state:set_display(display))
    elseif intent == "widget_display" or intent == "widget_display_aba" then
      widget:toggle_flag(4)
      if intent == "widget_display_aba" then
        widget:toggle_flag(4)
      end
    elseif intent == "flag_observable" then
      local schedule_display = widget._schedule_display
      t:patch_table(widget, "_schedule_display", function(self)
        schedule_display(self)
        release(captured)
      end)
      widget._options[4]:next(false)
    elseif intent == "display_ack" then
      widget._options[4]:next(widget._options[4]:snapshot(), { force = true })
      vim.schedule(function()
        release(captured)
      end)
    elseif intent == "disabled_compress" then
      widget:toggle_flag(3)
    elseif intent == "fold" then
      await(widget._action:collapse_all())
    elseif intent == "native_fold" then
      local resource = await(data:resolve(path .. "/directory"))
      await(session:fold(view:frame(), resource:node(), "toggle"))
    elseif intent == "root" then
      await(widget:set_root(fixture.directory()))
    elseif intent == "job" then
      await(session:operate(view, { kind = "create", path = "other-job" }))
      fixture.idle(widget)
    elseif intent == "focus" then
      vim.api.nvim_set_current_win(source_winnr)
      vim.api.nvim_set_current_win(view.winnr)
    elseif intent == "close" then
      widget:hide()
    else
      widget:dispose()
    end
    if intent ~= "flag_observable" and intent ~= "display_ack" then
      release(captured)
    end
    t.assert_eq(follows and "Applied" or "NoChange", await(navigation).kind)
    t.assert_true(vim.uv.fs_stat(target) ~= nil)
    if follows then
      followed(widget, target)
    end
    if intent == "pending_cursor" then
      t.assert_eq(expected, widget:get_cursor_filepath())
      vim.api.nvim_exec_autocmds("CursorMoved", { group = view._group, buf = view.bufnr, modeline = false })
    end
    if intent == "cursor" or intent == "pending_cursor" or intent == "shared" or intent == "focus" then
      fixture.idle(widget)
      t.assert_eq(expected, widget:get_cursor_filepath())
    end
  end)
end

t:test("cancelled preparation, failed admission and skipped overwrite do not follow or retain observers", function()
  for _, outcome in ipairs({ "cancel", "failed", "skipped" }) do
    local path = fixture.directory()
    fixture.write(path .. "/source")
    fixture.write(path .. "/existing")
    local widget = fixture.widget(path)
    local session, view = widget:context()
    fixture.cursor(widget, path .. "/source")
    local before = watches(view)
    t:patch_table(vim.ui, "input", function(_, done)
      done(outcome == "skipped" and "n" or nil)
    end)
    local request = { kind = "copy_to_path" }
    if outcome == "failed" then
      request.path = path .. "/existing/child"
    elseif outcome == "skipped" then
      request.path = path .. "/existing"
    end
    local operation = widget._action:operate(request)
    local ok = pcall(await, operation)
    fixture.idle(widget)
    if outcome == "failed" then
      t.assert_true(not ok or session.progress.error ~= nil or session._counts.failed > 0)
    elseif outcome == "skipped" then
      t.assert_eq(1, session._counts.skipped)
    end
    t.assert_eq(path .. "/source", widget:get_cursor_filepath())
    t.assert_true(vim.uv.fs_stat(path .. "/source") ~= nil)
    t.assert_eq(before, watches(view))
    widget:dispose()
  end
end)

t:test("partial directory copies leave navigation on the source and retain the successful files", function()
  local path = fixture.directory()
  for _, directory in ipairs({ "source", "target" }) do
    assert(vim.uv.fs_mkdir(path .. "/" .. directory, 448))
  end
  fixture.write(path .. "/source/conflict")
  fixture.write(path .. "/source/accepted")
  fixture.write(path .. "/target/conflict")
  local widget = fixture.widget(path)
  local session = widget:context()
  fixture.cursor(widget, path .. "/source")
  t:patch_table(vim.ui, "input", function(_, done)
    done("n")
  end)
  await(widget._action:operate({ kind = "copy_to_path", path = path .. "/target" }))
  fixture.idle(widget)
  t.assert_true(session._counts.skipped > 0)
  t.assert_true(vim.uv.fs_stat(path .. "/target/accepted") ~= nil)
  t.assert_eq(path .. "/source", widget:get_cursor_filepath())
end)

t:test("cancelling a running overwrite ignores its late answer and releases follow observers", function()
  local path = fixture.directory()
  fixture.write(path .. "/source")
  vim.fn.writefile({ "keep" }, path .. "/existing")
  local widget = fixture.widget(path)
  local session, view = widget:context()
  fixture.cursor(widget, path .. "/source")
  local before, answer = watches(view), nil
  t:patch_table(vim.ui, "input", function(_, done)
    answer = done
  end)
  await(widget._action:operate({ kind = "copy_to_path", path = path .. "/existing" }))
  t.wait_until(function()
    return answer ~= nil
  end, 10000)
  require("era.m.explorer.jobs").cancel(session)
  fixture.idle(widget)
  answer("y")
  t.assert_true(session.progress.cancelled)
  t.assert_eq("keep", vim.fn.readfile(path .. "/existing")[1])
  t.assert_eq(path .. "/source", widget:get_cursor_filepath())
  t.assert_eq(before, watches(view))
end)

t:test("an existing completion callback runs after unlock and can replace follow navigation", function()
  local path = fixture.directory()
  fixture.write(path .. "/source")
  fixture.write(path .. "/other")
  local widget = fixture.widget(path)
  local session, view = widget:context()
  fixture.cursor(widget, path .. "/source")
  local completed = 0
  local other = await(session.data:resolve(path .. "/other"))
  await(widget._action:operate({
    kind = "copy_to_path",
    path = path .. "/copied",
    on_complete = function(status, results)
      t.assert_eq(nil, status.error)
      t.assert_false(session.state:status().locked)
      t.assert_eq(path .. "/copied", results[#results].target)
      completed = completed + 1
      view:set_cursor(view:frame():position(other:node()))
    end,
  }))
  fixture.idle(widget)
  t.assert_eq(1, completed)
  t.assert_eq(path .. "/other", widget:get_cursor_filepath())
end)

t:test("pending annotation and queued parent navigation outrank a late transfer follow", function()
  local parent = fixture.directory()
  local path = parent .. "/root"
  assert(vim.uv.fs_mkdir(path, 448))
  fixture.write(path .. "/source")
  fixture.write(path .. "/other")
  local widget = fixture.widget(path)
  local session, view = widget:context()
  fixture.cursor(widget, path .. "/source")
  local target = path .. "/z-copy"
  local data, resolve = session.data, session.data.resolve
  local held, release_follow = Future.new_with_resolver()
  local captured, following
  t:patch_table(data, "resolve", function(self, requested)
    local pending = resolve(self, requested)
    if requested ~= target then
      return pending
    end
    return pending:then_(function(resource)
      captured = resource
      return held
    end)
  end)
  local navigate_path = session.navigate_path
  t:patch_table(session, "navigate_path", function(self, requested, reveal, valid)
    local pending = navigate_path(self, requested, reveal, valid)
    if requested == target then
      following = pending
    end
    return pending
  end)
  await(widget._action:operate({ kind = "copy_to_path", path = target }))
  t.wait_until(function()
    return captured ~= nil
  end, 10000)
  fixture.idle(widget)
  local other = await(data:resolve(path .. "/other"))
  local row = view:frame():position(other:node())
  local queried = false
  local query, release_annotation = Future.new_with_resolver()
  t:patch_table(data, "next_annotation", function()
    queried = true
    return query
  end)
  local annotation = widget._action:annotation("error", true)
  local navigating = widget._action:root("parent")
  t.wait_until(function()
    return queried
  end, 10000)
  release_follow(captured)
  local followed_result = await(following)
  release_annotation(row)
  await(annotation)
  local parent_result = await(navigating)
  fixture.idle(widget)
  t.assert_eq("NoChange", followed_result.kind)
  t.assert_eq("Applied", parent_result.kind)
  t.assert_eq(parent, widget:get_root_filepath())
end)

t:run()
