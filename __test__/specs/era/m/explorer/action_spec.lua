local t = require("__test__.support.harness").new()
local fixture = require("__test__.support.explorer").new(t)
local fs = require("__test__.support.fs")
local await, mark, write = fixture.await, fixture.mark, fixture.write

t:test("Normal mode switching and Visual union use one native selection", function()
  local path = t:tempdir()
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
  local path = t:tempdir()
  assert(vim.uv.fs_mkdir(path .. "/dest", 448))
  write(path .. "/a")
  local widget = fixture.widget(path)
  fixture.cursor(widget, path .. "/a")
  mark(widget, "copy")
  fixture.cursor(widget, path .. "/dest")
  await(widget:action():operate({ kind = "paste" }))
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
  local path = t:tempdir()
  assert(vim.uv.fs_mkdir(path .. "/dest", 448))
  write(path .. "/a")
  local widget = fixture.widget(path)
  local session, view = widget:context()
  local destination = await(session.data:resolve(path .. "/dest"))
  fixture.cursor(widget, path .. "/a")
  mark(widget, "copy")
  local frame = view:frame()
  local changed = widget:action():mark("cut")
  vim.api.nvim_win_set_cursor(view.winnr, { frame:position(destination:node()), 0 })
  local pasted = widget:action():operate({ kind = "paste" })
  await(changed)
  await(pasted)
  fixture.idle(widget)
  t.assert_eq("move", session.operation)
  t.assert_eq(nil, vim.uv.fs_stat(path .. "/a"), vim.inspect(session.results))
  t.assert_true(vim.uv.fs_stat(path .. "/dest/a") ~= nil)
end)

t:test("rename preserves a modified buffer and delete leaves that buffer alive", function()
  local path = t:tempdir()
  write(path .. "/a")
  local bufnr = t:buffer({ "unsaved content" }, { name = path .. "/a", listed = true })
  local widget = fixture.widget(path)
  fixture.cursor(widget, path .. "/a")
  await(widget:action():operate({ kind = "rename", name = "renamed" }))
  fixture.idle(widget)
  t.assert_eq(vim.uv.fs_realpath(path .. "/renamed"), vim.api.nvim_buf_get_name(bufnr))
  t.assert_eq("unsaved content", vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)[1])
  t.assert_true(vim.api.nvim_get_option_value("modified", { buf = bufnr }))
  fixture.cursor(widget, path .. "/renamed")
  t:patch_table(vim.ui, "input", function(options, done)
    t.assert_eq("confirmation", options.inputtype)
    done("y")
  end)
  await(widget:action():delete())
  fixture.idle(widget)
  t.assert_eq(nil, vim.uv.fs_stat(path .. "/renamed"))
  t.assert_true(vim.api.nvim_buf_is_valid(bufnr))
  t.assert_true(vim.api.nvim_get_option_value("modified", { buf = bufnr }))
end)

t:test("accepting Rename's default preserves a native Unix name containing a backslash", function()
  if stl.env.IS_WIN then
    t.skip("a backslash is a path separator on Windows")
  end
  local path, name = t:tempdir(), "a\\b"
  local widget = fixture.widget(path)
  await(widget:action():operate({ kind = "create", path = name }))
  fixture.idle(widget)
  write(path .. "/" .. name)
  fixture.cursor(widget, path .. "/" .. name)
  local default
  t:patch_table(vim.ui, "input", function(options, done)
    default = options.default
    done(default)
  end)
  await(widget:action():operate({ kind = "rename" }))
  fixture.idle(widget)
  t.assert_eq(name, default)
  t.assert_eq(nil, vim.uv.fs_stat(path .. "/b"))
  t.assert_eq("test", fs.read(path .. "/" .. name))
end)

t:test("a pending conflict survives closing the pane and cancellation preserves selection", function()
  local path = t:tempdir()
  assert(vim.uv.fs_mkdir(path .. "/dest", 448))
  write(path .. "/a")
  write(path .. "/dest/a")
  local widget = fixture.widget(path)
  fixture.cursor(widget, path .. "/a")
  mark(widget, "copy")
  fixture.cursor(widget, path .. "/dest")
  local confirmation
  t:patch_table(vim.ui, "input", function(_, done)
    confirmation = done
  end)
  local job = await(widget:action():operate({ kind = "paste" }))
  t.wait_until(function()
    return confirmation ~= nil and job:status().confirmation ~= nil
  end, 10000)
  local session = widget:context()
  widget:hide()
  t.assert_false(job:status().terminal)
  widget:focus()
  fixture.shown(widget)
  t.assert_true(session.state:status().locked)
  require("era.m.explorer.jobs").cancel(session)
  fixture.idle(widget)
  t.assert_true(job:status().cancelled)
  t.assert_eq("copy", session:mode())
  t.assert_true(vim.uv.fs_stat(path .. "/dest/a") ~= nil)
end)

t:test("rename applies LSP edits before IO and notifies only after a successful move", function()
  local path = t:tempdir()
  write(path .. "/a.lua")
  write(path .. "/use.lua")
  local bufnr = fixture.load_buffer(path .. "/use.lua")
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
  await(widget:action():operate({ kind = "rename", name = "renamed.lua" }))
  fixture.idle(widget)
  t.assert_eq(1, before)
  t.assert_eq(1, after)
  t.assert_eq("renamed", vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1])
  t.assert_true(vim.api.nvim_get_option_value("modified", { buf = bufnr }))
  write(path .. "/exists.lua")
  fixture.cursor(widget, path .. "/renamed.lua")
  t:patch_table(vim.ui, "input", function(options, done)
    t.assert_true(options.prompt:find("renamed.lua", 1, true) ~= nil)
    t.assert_true(options.prompt:find("exists.lua", 1, true) ~= nil)
    done("n")
  end)
  await(widget:action():operate({ kind = "rename", name = "exists.lua" }))
  fixture.idle(widget)
  t.assert_eq(1, before)
  t.assert_eq(1, after)
end)

t:test("trash configuration uses the platform tool and tool failure preserves the source", function()
  if not stl.env.IS_OSX and not (stl.env.IS_NIX and not stl.env.IS_WSL) then
    t.skip("trash uses a platform tool only on macOS and Linux outside WSL")
  end
  local path = t:tempdir()
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
  t:patch_table(vim.ui, "input", function(options, done)
    t.assert_eq("confirmation", options.inputtype)
    t.assert_true(options.prompt:match("^Trash ") ~= nil)
    done("yes")
  end)
  write(path .. "/a")
  local widget = fixture.widget(path)
  fixture.cursor(widget, path .. "/a")
  await(widget:action():delete())
  fixture.idle(widget)
  t.assert_eq(nil, vim.uv.fs_stat(path .. "/a"), vim.inspect(widget:context().results))
  t.assert_true(vim.uv.fs_stat(recycled .. "/a") ~= nil)
  vim.fn.writefile(
    { "#!/usr/bin/env python3", "import sys", 'sys.stderr.buffer.write(b"\\xff" * 4096)', "sys.exit(7)" },
    tool
  )
  write(path .. "/keep")
  await(widget:refresh())
  fixture.cursor(widget, path .. "/keep")
  await(widget:action():delete())
  fixture.idle(widget)
  t.assert_true(vim.uv.fs_stat(path .. "/keep") ~= nil)
  t.assert_eq(1, widget:context()._counts.failed)
  t.assert_true(#widget:context().results[1].error.message < 4096)
end)

t:test("an unrelated non-UTF8 buffer does not interrupt successful move synchronization", function()
  if stl.env.IS_WIN then
    t.skip("needs non-UTF-8 filenames")
  end
  local path = t:tempdir()
  write(path .. "/a")
  local raw = t:buffer(nil, { name = path .. "/" .. string.char(255), listed = true })
  local normal = fixture.load_buffer(path .. "/a", { "unsaved" })
  local widget = fixture.widget(path)
  fixture.cursor(widget, path .. "/a")
  await(widget:action():operate({ kind = "rename", name = "b" }))
  fixture.idle(widget)
  t.assert_eq(vim.uv.fs_realpath(path .. "/b"), vim.api.nvim_buf_get_name(normal))
  t.assert_eq("unsaved", vim.api.nvim_buf_get_lines(normal, 0, 1, false)[1])
  t.assert_true(vim.api.nvim_get_option_value("modified", { buf = normal }))
  t.assert_true(vim.api.nvim_buf_get_name(raw):find(string.char(255), 1, true) ~= nil)
end)

t:test("directory prompts lock and capture the source before cursor or filesystem changes", function()
  for _, remove in ipairs({ false, true }) do
    local message_offset = #fixture.messages
    local path = t:tempdir()
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
    widget:action():menu()
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
    t.assert_eq(
      not remove,
      vim.uv.fs_stat(path .. "/dest/a") ~= nil,
      vim.inspect({
        remove = remove,
        messages = vim.list_slice(fixture.messages, message_offset + 1),
        progress = session.progress,
        results = session.results,
        counts = session._counts,
      })
    )
    widget:dispose()
  end
end)

t:run()
