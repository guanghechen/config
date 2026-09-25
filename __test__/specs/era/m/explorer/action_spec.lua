---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.specs.era.m.explorer.action" ---@type string

local fixture = require("__test__.support.explorer").new("era.m.explorer.action")
local t, await, write, directory = fixture.t, fixture.await, fixture.write, fixture.directory

---@param widget                        era.m.explorer.Widget
---@param mark                          string
---@return nil
local function mark(widget, mark)
  local result = await(widget._action:mark(mark))
  local session, view = widget:context()
  if result.revisions then
    t.wait_until(function()
      return session.state._native:applicable(view:frame(), result.revisions.commit)
    end, 10000)
  end
end

t:test("Normal mode switching and Visual union use one native selection", function()
  local path = directory()
  write(path .. "/a")
  write(path .. "/b")
  local widget = fixture.widget(path)
  fixture.cursor(widget, path .. "/a")
  mark(widget, "copy")
  local session, view = widget:context()
  local revision = view:frame():header().selection_revision
  mark(widget, "cut")
  t.assert_eq(revision, view:frame():header().selection_revision)
  t.assert_eq("cut", session:mode(view:frame()))
  vim.cmd.normal({ args = { "Vj" }, bang = true })
  mark(widget, "copy")
  t.assert_eq("copy", session:mode(view:frame()))
  t.assert_eq(2, view:frame():header().summary.known_roots)
  t.assert_true(vim.api.nvim_get_mode().mode ~= "V")
end)

t:test("paste consumes selected sources and successful cleanup exits copy mode", function()
  local path = directory()
  assert(vim.uv.fs_mkdir(path .. "/dest", 448))
  write(path .. "/a")
  local widget = fixture.widget(path)
  fixture.cursor(widget, path .. "/a")
  mark(widget, "copy")
  fixture.cursor(widget, path .. "/dest")
  await(widget._action:operate("paste"))
  fixture.idle(widget)
  t.assert_true(vim.uv.fs_stat(path .. "/dest/a") ~= nil)
  t.assert_true(vim.uv.fs_stat(path .. "/a") ~= nil)
  local session, view = widget:context()
  t.wait_until(function()
    return session:mode(view:frame()) == nil
  end, 10000)
  t.assert_eq(1, session._counts.success)
end)

t:test("paste uses the committed purpose when cut is submitted before the frame redraw", function()
  local path = directory()
  assert(vim.uv.fs_mkdir(path .. "/dest", 448))
  write(path .. "/a")
  local widget = fixture.widget(path)
  local session, view = widget:context()
  local destination = await(session.data:resolve(path .. "/dest"))
  fixture.cursor(widget, path .. "/a")
  mark(widget, "copy")
  local frame = view:frame()
  local changed = widget._action:mark("cut")
  vim.api.nvim_win_set_cursor(view.winnr, { frame:position(destination:node()), 0 })
  local pasted = widget._action:operate("paste")
  await(changed)
  await(pasted)
  fixture.idle(widget)
  t.assert_eq("move", session.operation)
  t.assert_eq(nil, vim.uv.fs_stat(path .. "/a"), vim.inspect(session.results))
  t.assert_true(vim.uv.fs_stat(path .. "/dest/a") ~= nil)
end)

t:test("rename preserves a modified buffer and delete leaves that buffer alive", function()
  local path = directory()
  write(path .. "/a")
  local bufnr = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_buf_set_name(bufnr, path .. "/a")
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "unsaved content" })
  t:defer(function()
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end)
  local widget = fixture.widget(path)
  fixture.cursor(widget, path .. "/a")
  await(widget._action:operate("move", { rename = true, name = "renamed" }))
  fixture.idle(widget)
  t.assert_eq(vim.uv.fs_realpath(path .. "/renamed"), vim.api.nvim_buf_get_name(bufnr))
  t.assert_eq("unsaved content", vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)[1])
  t.assert_true(vim.api.nvim_get_option_value("modified", { buf = bufnr }))
  fixture.cursor(widget, path .. "/renamed")
  t:patch_table(vim.ui, "select", function(items, _, done)
    done(items[2], 2)
  end)
  await(widget._action:delete())
  fixture.idle(widget)
  t.assert_eq(nil, vim.uv.fs_stat(path .. "/renamed"))
  t.assert_true(vim.api.nvim_buf_is_valid(bufnr))
  t.assert_true(vim.api.nvim_get_option_value("modified", { buf = bufnr }))
end)

t:test("accepting Rename's default preserves a native Unix name containing a backslash", function()
  if stl.env.IS_WIN then
    return
  end
  local path, name = directory(), "a\\b"
  local widget = fixture.widget(path)
  await(widget._action:operate("create", { path = name }))
  fixture.idle(widget)
  write(path .. "/" .. name)
  fixture.cursor(widget, path .. "/" .. name)
  local default
  t:patch_table(vim.ui, "input", function(options, done)
    default = options.default
    done(default)
  end)
  await(widget._action:operate("move", { rename = true }))
  fixture.idle(widget)
  t.assert_eq(name, default)
  t.assert_eq(nil, vim.uv.fs_stat(path .. "/b"))
  local fd = assert(vim.uv.fs_open(path .. "/" .. name, "r", 384))
  local content = assert(vim.uv.fs_read(fd, 4, 0))
  assert(vim.uv.fs_close(fd))
  t.assert_eq("test", content)
end)

t:test("a pending conflict survives closing the pane and cancellation preserves selection", function()
  local path = directory()
  assert(vim.uv.fs_mkdir(path .. "/dest", 448))
  write(path .. "/a")
  write(path .. "/dest/a")
  local widget = fixture.widget(path)
  fixture.cursor(widget, path .. "/a")
  mark(widget, "copy")
  fixture.cursor(widget, path .. "/dest")
  local confirmation
  t:patch_table(vim.ui, "select", function(_, _, done)
    confirmation = done
  end)
  local job = await(widget._action:operate("paste"))
  t.wait_until(function()
    return confirmation ~= nil and job:status().confirmation ~= nil
  end, 10000)
  local session = widget._session
  widget:hide()
  t.assert_false(job:status().terminal)
  widget:focus()
  t.wait_until(function()
    local view = widget._views[vim.api.nvim_get_current_tabpage()]
    return view and view:frame()
  end, 10000)
  t.assert_true(session.state:status().locked)
  require("era.m.explorer.jobs").cancel(session)
  fixture.idle(widget)
  t.assert_true(job:status().cancelled)
  t.assert_eq("copy", session:mode())
  t.assert_true(vim.uv.fs_stat(path .. "/dest/a") ~= nil)
end)

t:test("new relative file creates parents, reveals it, and opens in a source window", function()
  local path = directory()
  local target = vim.api.nvim_get_current_win()
  t:patch_table(dot.win, "pick_sourcefile", function()
    return target
  end)
  t:patch_table(vim.ui, "input", function(_, done)
    done("notes/todo")
  end)
  local widget = fixture.widget(path)
  await(widget._action:create(false))
  fixture.idle(widget)
  t.wait_until(function()
    return vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(target)) == vim.uv.fs_realpath(path .. "/notes/todo")
  end, 10000)
  t.assert_eq(target, vim.api.nvim_get_current_win())
  t.assert_true(vim.uv.fs_stat(path .. "/notes/todo") ~= nil)
end)

t:test("creation through a directory link reveals the created logical occurrence", function()
  local path = directory()
  assert(vim.uv.fs_mkdir(path .. "/target", 448))
  assert(vim.uv.fs_symlink("target", path .. "/alias", { dir = true }))
  local target = vim.api.nvim_get_current_win()
  t:patch_table(dot.win, "pick_sourcefile", function()
    return target
  end)
  t:patch_table(vim.ui, "input", function(_, done)
    done("notes/todo")
  end)
  local widget = fixture.widget(path)
  fixture.cursor(widget, path .. "/alias")
  await(widget._action:create(false))
  fixture.idle(widget)
  t.wait_until(function()
    return vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(target))
        == vim.uv.fs_realpath(path .. "/target/notes/todo")
      and widget:get_cursor_filepath() == path .. "/alias/notes/todo"
  end, 10000)
  t.assert_eq(path, widget:get_root_filepath())
  t.assert_eq(target, vim.api.nvim_get_current_win())
end)

t:test("completion and confirmation release selection while the progress timer is still queued", function()
  local path = directory()
  local widget = fixture.widget(path)
  local session, view = widget:context()
  local callbacks, completed = {}, 0
  local defer = vim.defer_fn
  t:patch_table(vim, "defer_fn", function(callback, delay)
    if callbacks and delay == 40 and debug.getinfo(callback, "S").source:find("era/m/explorer/jobs.lua", 1, true) then
      callbacks[#callbacks + 1] = callback
      return
    end
    return defer(callback, delay)
  end)
  t:defer(function()
    local held = callbacks
    callbacks = nil
    for _, callback in ipairs(held) do
      callback()
    end
  end)

  for _, name in ipairs({ "first", "second" }) do
    local job = await(session:operate(view, "create", {
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
    end, 1000, "completed IO must not wait for the progress timer")
    t.assert_true(vim.uv.fs_stat(path .. "/" .. name) ~= nil)
  end
  fixture.cursor(widget, path .. "/first")
  local confirmations = 0
  t:patch_table(vim.ui, "select", function(items, _, done)
    t.assert_eq("Skip", items[1])
    confirmations = confirmations + 1
    done(items[1], 1)
  end)
  local copy = await(session:operate(view, "copy", { to_path = path .. "/second" }))
  t.wait_until(function()
    return session.job == nil
  end, 1000, "a new conflict and its terminal result must not wait for progress refresh")
  t.assert_eq(1, confirmations)
  t.assert_eq("skipped", copy:results(1, 1)[1].status)
  t.assert_true(#callbacks > 0, "the low-frequency progress timer was held")
  t.assert_eq(2, completed)
  t.assert_false(require("era.m.explorer.jobs").pending())
end)

t:test("cancelling preparation settles before a late prompt and permits a new operation", function()
  local path = directory()
  local widget = fixture.widget(path)
  local session, view = widget:context()
  local answered
  t:patch_table(vim.ui, "input", function(_, done)
    answered = done
  end)
  local preparing = session:operate(view, "create", {})
  t.wait_until(function()
    return answered ~= nil
  end, 10000)
  require("era.m.explorer.jobs").cancel(session)
  await(preparing)
  fixture.idle(widget)
  t.assert_false(require("era.m.explorer.jobs").pending())
  await(session:operate(view, "create", { path = "accepted" }))
  answered("late")
  fixture.idle(widget)
  t.assert_true(vim.uv.fs_stat(path .. "/accepted") ~= nil)
  t.assert_eq(nil, vim.uv.fs_stat(path .. "/late"))
  local again = session:operate(view, "create", {})
  t.wait_until(function()
    return session.preparing and session._preparation.resume ~= nil
  end, 10000)
  widget:dispose()
  await(again)
  t.assert_eq(nil, session.native)
  t.assert_eq(nil, session.data)
end)

t:test("open captures its input before asynchronous selection inspection and preserves selection", function()
  local path = directory()
  write(path .. "/a")
  write(path .. "/b")
  local target = vim.api.nvim_get_current_win()
  t:patch_table(dot.win, "pick_sourcefile", function()
    return target
  end)
  local widget = fixture.widget(path)
  local session, view = widget:context()
  local other = await(session.data:resolve(path .. "/b"))
  fixture.cursor(widget, path .. "/a")
  local opening = widget._action:open()
  vim.api.nvim_win_set_cursor(view.winnr, { view:frame():position(other:node()), 0 })
  await(opening)
  t.assert_eq(vim.uv.fs_realpath(path .. "/a"), vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(target)))
  widget:focus()
  fixture.cursor(widget, path .. "/a")
  mark(widget, "copy")
  t:patch_table(dot.win, "pick_sourcefile", function()
    return nil
  end)
  await(widget._action:open())
  t.assert_eq(view.winnr, vim.api.nvim_get_current_win())
  t.assert_eq("copy", session:mode())
end)

t:test("rename applies LSP edits before IO and notifies only after a successful move", function()
  local path = directory()
  write(path .. "/a.lua")
  write(path .. "/use.lua")
  local bufnr = vim.fn.bufadd(path .. "/use.lua")
  vim.fn.bufload(bufnr)
  t:defer(function()
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end)
  local before, after = 0, 0
  local client = {
    offset_encoding = "utf-16",
    supports_method = function(_, method)
      return method == "workspace/willRenameFiles" or method == "workspace/didRenameFiles"
    end,
    request = function(_, method, changes, done)
      t.assert_eq("workspace/willRenameFiles", method)
      t.assert_true(vim.uv.fs_stat(path .. "/a.lua") ~= nil)
      t.assert_eq(vim.uri_from_fname(vim.uv.fs_realpath(path) .. "/renamed.lua"), changes.files[1].newUri)
      before = before + 1
      vim.schedule(function()
        done(nil, {
          changes = {
            [vim.uri_from_bufnr(bufnr)] = {
              {
                range = { start = { line = 0, character = 0 }, ["end"] = { line = 0, character = 4 } },
                newText = "renamed",
              },
            },
          },
        })
      end)
      return true, 1
    end,
    cancel_request = function() end,
    notify = function(_, method)
      t.assert_eq("workspace/didRenameFiles", method)
      t.assert_eq(nil, vim.uv.fs_stat(path .. "/a.lua"))
      t.assert_true(vim.uv.fs_stat(path .. "/renamed.lua") ~= nil)
      after = after + 1
    end,
  }
  t:patch_table(vim.lsp, "get_clients", function(options)
    return options and options.bufnr and {} or { client }
  end)
  local widget = fixture.widget(path)
  fixture.cursor(widget, path .. "/a.lua")
  await(widget._action:operate("move", { rename = true, name = "renamed.lua" }))
  fixture.idle(widget)
  t.assert_eq(1, before)
  t.assert_eq(1, after)
  t.assert_eq("renamed", vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1])
  t.assert_true(vim.api.nvim_get_option_value("modified", { buf = bufnr }))
  write(path .. "/exists.lua")
  fixture.cursor(widget, path .. "/renamed.lua")
  t:patch_table(vim.ui, "select", function(items, options, done)
    t.assert_true(options.prompt:find("renamed.lua", 1, true) ~= nil)
    t.assert_true(options.prompt:find("exists.lua", 1, true) ~= nil)
    done(items[1], 1)
  end)
  await(widget._action:operate("move", { rename = true, name = "exists.lua" }))
  fixture.idle(widget)
  t.assert_eq(1, before)
  t.assert_eq(1, after)
end)

t:test("trash configuration uses the platform tool and tool failure preserves the source", function()
  if not stl.env.IS_OSX and not (stl.env.IS_NIX and not stl.env.IS_WSL) then
    return
  end
  local path = directory()
  local bin, recycled = path .. "/bin", path .. "/recycled"
  assert(vim.uv.fs_mkdir(bin, 448))
  assert(vim.uv.fs_mkdir(recycled, 448))
  local tool = bin .. (stl.env.IS_OSX and "/trash" or "/gio")
  vim.fn.writefile(
    { "#!/bin/sh", 'for target in "$@"; do :; done', '/bin/mv "$target" "$FILETREE_TRASH_TEST_DEST/"' },
    tool
  )
  assert(vim.uv.fs_chmod(tool, 448))
  local original_path, original_destination = vim.env.PATH, vim.env.FILETREE_TRASH_TEST_DEST
  vim.env.PATH, vim.env.FILETREE_TRASH_TEST_DEST = bin .. ":" .. original_path, recycled
  t:defer(function()
    vim.env.PATH, vim.env.FILETREE_TRASH_TEST_DEST = original_path, original_destination
  end)
  t:patch_table(dot.context.explorer, "trash", stl.c.Observable.from_value(true))
  t:patch_table(vim.ui, "select", function(items, _, done)
    t.assert_eq("Move to trash", items[2])
    done(items[2], 2)
  end)
  write(path .. "/a")
  local widget = fixture.widget(path)
  fixture.cursor(widget, path .. "/a")
  await(widget._action:delete())
  fixture.idle(widget)
  t.assert_eq(nil, vim.uv.fs_stat(path .. "/a"), vim.inspect(widget._session.results))
  t.assert_true(vim.uv.fs_stat(recycled .. "/a") ~= nil)
  vim.fn.writefile(
    { "#!/usr/bin/env python3", "import sys", 'sys.stderr.buffer.write(b"\\xff" * 4096)', "sys.exit(7)" },
    tool
  )
  write(path .. "/keep")
  await(widget:refresh())
  fixture.cursor(widget, path .. "/keep")
  await(widget._action:delete())
  fixture.idle(widget)
  t.assert_true(vim.uv.fs_stat(path .. "/keep") ~= nil)
  t.assert_eq(1, widget._session._counts.failed)
  t.assert_true(#widget._session.results[1].error.message < 4096)
end)

t:test("copy and move to a complete path create parents and keep rename within the current parent", function()
  local path = directory()
  write(path .. "/a")
  local widget = fixture.widget(path)
  fixture.cursor(widget, path .. "/a")
  await(widget._action:operate("copy", { to_path = path .. "/new/nested/duplicate" }))
  fixture.idle(widget)
  t.assert_true(vim.uv.fs_stat(path .. "/a") ~= nil)
  t.assert_true(vim.uv.fs_stat(path .. "/new/nested/duplicate") ~= nil)
  fixture.cursor(widget, path .. "/a")
  await(widget._action:operate("move", { to_path = path .. "/moved/renamed" }))
  fixture.idle(widget)
  t.assert_eq(nil, vim.uv.fs_stat(path .. "/a"))
  t.assert_true(vim.uv.fs_stat(path .. "/moved/renamed") ~= nil)
  await(widget:reveal(path .. "/moved/renamed"))
  fixture.cursor(widget, path .. "/moved/renamed")
  t:patch_table(vim.ui, "input", function(options, done)
    t.assert_eq("renamed", options.default)
    done("final")
  end)
  await(widget._action:operate("move", { rename = true }))
  fixture.idle(widget)
  t.assert_true(vim.uv.fs_stat(path .. "/moved/final") ~= nil)
end)

t:test("copy to an alias inside the source is rejected before creating missing parents", function()
  if stl.env.IS_WIN then
    return
  end
  local path = directory()
  assert(vim.uv.fs_mkdir(path .. "/source", 448))
  write(path .. "/source/a")
  assert(vim.uv.fs_symlink("source", path .. "/alias"))
  local widget = fixture.widget(path)
  fixture.cursor(widget, path .. "/source")
  local operation = widget._action:operate("copy", { to_path = path .. "/alias/created/copy" })
  t.wait_until(function()
    return operation:is_done()
  end, 10000)
  t.assert_true(operation:is_failed())
  t.assert_true(operation:get_error():find("inside its source", 1, true) ~= nil)
  t.assert_eq(nil, vim.uv.fs_stat(path .. "/source/created"))
  fixture.idle(widget)
end)

t:test("an unrelated non-UTF8 buffer does not interrupt successful move synchronization", function()
  if stl.env.IS_WIN then
    return
  end
  local path = directory()
  write(path .. "/a")
  local raw, normal = vim.api.nvim_create_buf(true, false), vim.fn.bufadd(path .. "/a")
  vim.fn.bufload(normal)
  vim.api.nvim_buf_set_name(raw, path .. "/" .. string.char(255))
  vim.api.nvim_buf_set_lines(normal, 0, -1, false, { "unsaved" })
  t:defer(function()
    for _, bufnr in ipairs({ raw, normal }) do
      if vim.api.nvim_buf_is_valid(bufnr) then
        vim.api.nvim_buf_delete(bufnr, { force = true })
      end
    end
  end)
  local widget = fixture.widget(path)
  fixture.cursor(widget, path .. "/a")
  await(widget._action:operate("move", { rename = true, name = "b" }))
  fixture.idle(widget)
  t.assert_eq(vim.uv.fs_realpath(path .. "/b"), vim.api.nvim_buf_get_name(normal))
  t.assert_eq("unsaved", vim.api.nvim_buf_get_lines(normal, 0, 1, false)[1])
  t.assert_true(vim.api.nvim_get_option_value("modified", { buf = normal }))
  t.assert_true(vim.api.nvim_buf_get_name(raw):find(string.char(255), 1, true) ~= nil)
end)

t:test("directory prompts lock and capture the source before cursor or filesystem changes", function()
  for _, remove in ipairs({ false, true }) do
    local path = directory()
    assert(vim.uv.fs_mkdir(path .. "/dest", 448))
    write(path .. "/a")
    write(path .. "/b")
    local widget = fixture.widget(path)
    local session, view = widget:context()
    fixture.cursor(widget, path .. "/a")
    local answer
    t:patch_table(vim.ui, "select", function(_, _, done)
      done("Move to directory")
    end)
    t:patch_table(vim.ui, "input", function(_, done)
      answer = done
    end)
    widget._action:menu()
    t.wait_until(function()
      return answer ~= nil
    end, 10000)
    t.assert_true(session.preparing and session.state:status().locked, "prompt must already own its source lock")
    if remove then
      assert(vim.uv.fs_unlink(path .. "/a"))
    end
    local other = await(session.data:resolve(path .. "/b"))
    vim.api.nvim_win_set_cursor(view.winnr, { assert(view:frame():position(other:node())), 0 })
    answer(path .. "/dest")
    fixture.idle(widget)
    t.assert_true(vim.uv.fs_stat(path .. "/b") ~= nil)
    t.assert_nil(vim.uv.fs_stat(path .. "/dest/b"), "a delayed prompt must never move the new cursor item")
    t.assert_eq(not remove, vim.uv.fs_stat(path .. "/dest/a") ~= nil)
    widget:dispose()
  end
end)

t:run()
