---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.specs.era.m.explorer.widget" ---@type string

local fixture = require("__test__.support.explorer").new("era.m.explorer.widget")
local t, await, write, directory = fixture.t, fixture.await, fixture.write, fixture.directory

t:test("real panes use native Filetree, switch Tree/List, and preserve state across close", function()
  local path = directory()
  assert(vim.uv.fs_mkdir(path .. "/sub", 448))
  write(path .. "/sub/file")
  write(path .. "/a")
  local widget = fixture.widget(path)
  local session, view = widget:context()
  t.assert_eq("tree", view:frame():header().mode)
  t.assert_eq(2, view:frame():header().row_count)
  t.assert_eq("explorer", vim.api.nvim_get_option_value("filetype", { buf = view.bufnr }))
  t.assert_eq("", vim.api.nvim_get_option_value("statuscolumn", { win = view.winnr }))
  fixture.cursor(widget, path .. "/a")
  await(widget._action:mark("copy"))
  t.wait_until(function()
    return session:mode(view:frame()) == "copy"
  end, 10000)
  widget:toggle_flag(2)
  t.wait_until(function()
    return view:frame():header().mode == "list" and view:frame():header().row_count == 3
  end, 10000)
  t.assert_true(
    table.concat(vim.api.nvim_buf_get_lines(view.bufnr, 0, -1, false), "\n"):find("sub/file", 1, true) ~= nil
  )
  local state_id = view:frame():header().state_id
  widget:hide()
  t.assert_false(widget:isvisible())
  widget:focus()
  t.wait_until(function()
    local current = widget._views[vim.api.nvim_get_current_tabpage()]
    return current and current:frame() and current:frame():header().row_count == 3
  end, 10000)
  local _, reopened = widget:context()
  t.assert_eq(state_id, reopened:frame():header().state_id)
  t.assert_eq("copy", session:mode(reopened:frame()))
  for _, mode in ipairs({ "n", "x" }) do
    for _, mapping in ipairs(vim.api.nvim_buf_get_keymap(reopened.bufnr, mode)) do
      t.assert_true(mapping.lhs ~= "<Esc>", "Explorer must not bind Escape")
    end
  end
end)

t:test("reveal expands a nested file and root navigation retains selection", function()
  local path = directory()
  assert(vim.uv.fs_mkdir(path .. "/sub", 448))
  write(path .. "/sub/file")
  write(path .. "/a")
  local widget = fixture.widget(path)
  fixture.cursor(widget, path .. "/a")
  await(widget._action:mark("cut"))
  await(widget:reveal(path .. "/sub/file"))
  local session, view = widget:context()
  local resource = await(session.data:resolve(path .. "/sub/file"))
  t.wait_until(function()
    return view:frame():header().cursor == resource:node()
  end, 10000)
  t.assert_eq("cut", session:mode(view:frame()))
  await(widget:set_root(path .. "/sub"))
  t.wait_until(function()
    return session:root(view:frame()):path() == path .. "/sub"
  end, 10000)
  await(widget._action:root("previous"))
  t.wait_until(function()
    return session:root(view:frame()):path() == path
  end, 10000)
  t.assert_eq("cut", session:mode(view:frame()))
end)

t:test("shared data keeps independent states and subscriptions survive the first owner closing", function()
  local path = directory()
  write(path .. "/a")
  local first = fixture.widget(path)
  local shared = first._session.data
  fixture.cursor(first, path .. "/a")
  await(first._action:mark("copy"))
  local second = fixture.widget(path, { data = shared })
  local session, view = second:context()
  t.assert_true(session.state:snapshot():header().state_id ~= first._session.state:snapshot():header().state_id)
  t.assert_eq(nil, session:mode(view:frame()))
  t.assert_eq(first._session._subscriptions, session._subscriptions)
  first:dispose()
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(bufnr, path .. "/a")
  local namespace = vim.api.nvim_create_namespace("shared-explorer-input")
  t:defer(function()
    vim.diagnostic.reset(namespace)
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end)
  vim.diagnostic.set(namespace, bufnr, { { lnum = 0, col = 0, message = "error", severity = 1 } })
  t.wait_until(function()
    return view._filetree_annotations and view._filetree_annotations.rows[1].diagnostics[1] == 1
  end, 10000)
  local third = fixture.widget(path, { session = session })
  local same, other_view = third:context()
  t.assert_eq(session, same)
  t.assert_eq(view:frame():header().state_id, other_view:frame():header().state_id)
  second:toggle_flag(2)
  t.wait_until(function()
    return other_view:frame():header().mode == "list" and third:get_display().mode == "list"
  end, 10000)
  third:toggle_flag(2)
  t.wait_until(function()
    return view:frame():header().mode == "tree" and second:get_display().mode == "tree"
  end, 10000)
end)

t:test("reveal synchronizes display flags and later toggles preserve the revealed visibility", function()
  local path = directory()
  write(path .. "/.hidden")
  write(path .. "/a")
  local widget = fixture.widget(path)
  widget:toggle_flag(4)
  t.wait_until(function()
    return widget._session.state:display().show_hidden == false
  end, 10000)
  await(widget:reveal(path .. "/.hidden"))
  t.wait_until(function()
    return widget:show_hidden()
  end, 10000)
  widget:toggle_flag(2)
  t.wait_until(function()
    return widget._session.state:display().mode == "list"
  end, 10000)
  t.assert_true(widget._session.state:display().show_hidden)
  t.assert_eq("ancestry", widget._session.state:display().list_text)
  widget:toggle_flag(4)
  t.wait_until(function()
    return not widget:show_hidden() and not widget._display_scheduled
  end, 10000)
  widget:toggle_flag(4)
  widget:toggle_flag(4)
  t.wait_until(function()
    return not widget._display_scheduled
  end, 10000)
  t.assert_false(widget:show_hidden())
end)

t:test("concurrent shared-session flag changes retain both partial updates", function()
  local path = directory()
  write(path .. "/a")
  write(path .. "/.hidden")
  local first = fixture.widget(path)
  local second = fixture.widget(path, { session = first._session })
  first:toggle_flag(2)
  second:toggle_flag(4)
  t.wait_until(function()
    local display = first._session.state:display()
    return display.mode == "list"
      and not display.show_hidden
      and first:get_display().mode == "list"
      and second:get_display().mode == "list"
      and not first:show_hidden()
      and not second:show_hidden()
  end, 10000)
end)

t:test("sharing flag observables cannot turn native display acknowledgements into new input", function()
  for _, order in ipairs({ { 4, 2 }, { 2, 4 } }) do
    local path = directory()
    write(path .. "/a")
    local first = fixture.widget(path)
    local second = fixture.widget(path, {
      session = first._session,
      o_flag_selected = first._options[1],
      o_flag_viewtype = first._options[2],
      o_flag_foldempty = first._options[3],
      o_flag_hidden = first._options[4],
    })
    first:toggle_flag(order[1])
    second:toggle_flag(order[2])
    t.wait_until(function()
      return first:get_display().mode == "list"
        and not first:show_hidden()
        and not first._display_scheduled
        and not second._display_scheduled
    end, 10000)
    t.assert_eq("list", second:get_display().mode)
    t.assert_false(second:show_hidden())
    first:dispose()
    second:dispose()
  end
end)

t:test("a removed root can navigate to its parent and a recreated workspace", function()
  local base = directory()
  local path = base .. "/workspace"
  assert(vim.uv.fs_mkdir(path, 448))
  local widget = fixture.widget(path)
  assert(vim.uv.fs_rmdir(path))
  t.wait_until(function()
    return widget._session._root_error == true
  end, 10000)
  await(widget._action:root("parent"))
  local session, view = widget:context()
  t.wait_until(function()
    local frame = view:frame()
    return frame:source():node(frame:header().root.node) ~= nil and session:root(frame):path() == base
  end, 10000)
  assert(vim.uv.fs_mkdir(path, 448))
  await(widget._action:root("workspace"))
  t.wait_until(function()
    return session:root(view:frame()):path() == path
  end, 10000)
end)

t:test("manual refresh recovers a desynced surface after automatic recovery also fails", function()
  local path = directory()
  write(path .. "/a")
  local widget = fixture.widget(path)
  local session, view = widget:context()
  local set_lines = vim.api.nvim_buf_set_lines
  local failures = 0
  t:patch_table(vim.api, "nvim_buf_set_lines", function(bufnr, ...)
    if bufnr == view.bufnr and failures < 2 then
      failures = failures + 1
      error("transient Explorer publication failure")
    end
    return set_lines(bufnr, ...)
  end)
  write(path .. "/b")
  await(session:refresh())
  t.wait_until(function()
    return failures == 2 and view:status().desynced and not view:status().preparing
  end, 10000)
  await(widget:refresh())
  t.wait_until(function()
    return view:frame() and view:frame():header().row_count == 2 and not view:status().desynced
  end, 10000, "Widget refresh must recover the owned surface")
  t.assert_eq(2, vim.api.nvim_buf_line_count(view.bufnr))
end)

t:test("hide and reopen release every Explorer buffer identity", function()
  local path = directory()
  write(path .. "/a")
  local before = {}
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    before[bufnr] = true
  end
  local widget = fixture.widget(path)
  for _ = 1, 10 do
    widget:hide()
    t.wait_until(function()
      return widget._session.data:watch_status().directories == 0
    end, 10000)
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
      t.assert_true(before[bufnr], "orphan buffer after hide: " .. vim.api.nvim_buf_get_name(bufnr))
    end
    widget:focus()
    t.wait_until(function()
      local view = widget._views[vim.api.nvim_get_current_tabpage()]
      return view and view:frame() and view:frame():header().row_count == 1
    end, 10000)
  end
end)

t:test("refreshing a healthy unchanged pane preserves its body publication", function()
  local path = directory()
  write(path .. "/a")
  local widget = fixture.widget(path)
  local session, view = widget:context()
  t.wait_until(function()
    return not view:status().preparing and session.state._native:applicable(view:frame())
  end, 10000)
  local tick = vim.api.nvim_buf_get_changedtick(view.bufnr)
  await(widget:refresh())
  fixture.idle(widget)
  t.wait_until(function()
    return not view:status().preparing and session.state._native:applicable(view:frame())
  end, 10000)
  t.assert_eq(tick, vim.api.nvim_buf_get_changedtick(view.bufnr), "healthy refresh must not force a full body reset")
end)

t:test("reveal leaves a removed display root for an existing external file", function()
  local path = directory()
  local workspace = path .. "/workspace"
  assert(vim.uv.fs_mkdir(workspace, 448))
  write(path .. "/external")
  local widget = fixture.widget(workspace)
  assert(vim.uv.fs_rmdir(workspace))
  await(widget:refresh())
  await(widget:reveal(path .. "/external"))
  t.wait_until(function()
    return widget:get_cursor_filepath() == path .. "/external"
  end, 10000)
  t.assert_eq(path, widget:get_root_filepath())
end)

t:test("empty background panes release obsolete resource snapshots", function()
  local path = directory()
  for index = 1, 1000 do
    write(path .. "/file-" .. index)
  end
  local widget = fixture.widget(path)
  local session, view = widget:context()
  await(session.data:set_diagnostics(1, 1, 1, path .. "/file-1", { 1, 0, 0, 0 }))
  t.wait_until(function()
    return view:frame():header().row_count == 1000
      and view._filetree_annotations ~= nil
      and view._filetree_pending == nil
      and not session.data._native:is_busy()
      and view:frame():header().data_revision == session.data:source():revision()
  end, 10000)
  collectgarbage("collect")
  local before = session.data._native:stats().retained_bytes

  local tabnr = vim.api.nvim_get_current_tabpage()
  vim.cmd.tabnew()
  local other_tabnr = vim.api.nvim_get_current_tabpage()
  t:defer(function()
    if vim.api.nvim_tabpage_is_valid(other_tabnr) then
      vim.api.nvim_set_current_tabpage(other_tabnr)
      vim.cmd.tabclose()
    end
    if vim.api.nvim_tabpage_is_valid(tabnr) then
      vim.api.nvim_set_current_tabpage(tabnr)
    end
  end)
  for index = 1, 1000 do
    assert(vim.uv.fs_unlink(path .. "/file-" .. index))
  end
  await(session:refresh())
  t.wait_until(function()
    return view:frame():header().row_count == 0 and not session.data._native:is_busy()
  end, 10000)
  t.assert_eq(other_tabnr, vim.api.nvim_get_current_tabpage())
  t.wait_until(function()
    collectgarbage("collect")
    return session.data._native:stats().retained_bytes < before / 2
  end, 10000, "an empty background pane retained its previous directory snapshot")
end)

t:run()
