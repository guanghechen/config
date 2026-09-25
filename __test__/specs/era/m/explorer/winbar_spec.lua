---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.specs.era.m.explorer.winbar" ---@type string

local fixture = require("__test__.support.explorer").new("era.m.explorer.winbar")
local t, await, directory, write = fixture.t, fixture.await, fixture.directory, fixture.write

t:test("winbar follows display root and four fixed flags when tabline is hidden", function()
  local before = vim.o.showtabline
  t:defer(function()
    vim.o.showtabline = before
  end)
  vim.o.showtabline = 0
  local path = directory()
  write(path .. "/.hidden")
  write(path .. "/visible")
  local widget = fixture.widget(path)
  local _, view = widget:context()
  local winbar = vim.api.nvim_get_option_value("winbar", { win = view.winnr })
  t.assert_true(
    winbar:find(path, 1, true) ~= nil,
    "winbar="
      .. vim.inspect(winbar)
      .. ", showtabline="
      .. vim.o.showtabline
      .. ", cached="
      .. tostring(widget._titles[view.winnr])
  )
  for _, callback in ipairs(widget._callbacks) do
    t.assert_true(winbar:find(callback, 1, true) ~= nil)
  end
  local _, enabled = winbar:gsub("picker_flag_blue", "")
  t.assert_eq(3, enabled)
  widget:toggle_flag(4)
  t.wait_until(function()
    return view:frame():header().row_count == 1
  end, 10000)
  winbar = vim.api.nvim_get_option_value("winbar", { win = view.winnr })
  _, enabled = winbar:gsub("picker_flag_blue", "")
  t.assert_eq(2, enabled)
  widget:toggle_flag(2)
  t.wait_until(function()
    return view:frame():header().mode == "list"
  end, 10000)
  local compact = widget._options[3]:snapshot()
  widget:toggle_flag(3)
  t.assert_eq(compact, widget._options[3]:snapshot())
  vim.o.showtabline = 2
  widget:render_winbar()
  t.assert_eq("", vim.api.nvim_get_option_value("winbar", { win = view.winnr }))
end)

t:test("tabline visibility and Explorer OptionSet settle without a redraw feedback loop", function()
  local path = directory()
  write(path .. "/file")
  local ui = require("__test__.support.ui").new()
  t:defer(function()
    ui:close()
  end)
  ui:rpc("nvim_ui_attach", 80, 24, { rgb = true, ext_linegrid = true })
  ui:rpc(
    "nvim_exec_lua",
    [=[
    local root, path = ...
    vim.opt.runtimepath:prepend(root)
    package.path = root .. "/?.lua;" .. package.path
    local fixture = require("__test__.support.explorer").new("explorer-tabline")
    vim.o.showtabline = 0
    local widget = fixture.widget(path)
    winbar_probe = { widget = widget, shown = false, renders = 0 }
    local render = widget.render_winbar
    widget.render_winbar = function(self)
      winbar_probe.renders = winbar_probe.renders + 1
      render(self)
    end
    era.widget.explorer.widget = widget
    dot.context.flight.devmode:next(false, { silent = true })
    dot.tab.resolve = function()
      return { bufs = winbar_probe.shown and { 1, 2 } or { 1 } }
    end
    -- Keep real tabline visibility, Observable delivery and OptionSet; omit bar data providers.
    era.m.nvimbar.Nvimbar = {
      new = function()
        return { place = function(self) return self end, refresh = function() end }
      end,
    }
    require("era.dressing.tabline").dressing()
  ]=],
    { assert(vim.uv.cwd()), path }
  )

  for _, shown in ipairs({ false, true, false }) do
    ui:rpc("nvim_exec_lua", "winbar_probe.shown = ...; dot.state.status.dirtier_tabline:mark_dirty()", { shown })
    t.wait_until(function()
      return ui:rpc("nvim_get_option_value", "showtabline", {}) == (shown and 2 or 0)
    end, 3000)
    vim.wait(100, function()
      return false
    end, 5)
    local before = ui:rpc("nvim_exec_lua", "return winbar_probe.renders", {})
    vim.wait(50, function()
      return false
    end, 5)
    t.assert_eq(before, ui:rpc("nvim_exec_lua", "return winbar_probe.renders", {}), "idle redraws must settle")
    local title = ui:rpc(
      "nvim_exec_lua",
      "return vim.api.nvim_get_option_value('winbar', {win = winbar_probe.widget:get_winnr()})",
      {}
    )
    t.assert_true(shown and title == "" or not shown and title:find(path, 1, true) ~= nil)
    ui:rpc("nvim_exec_lua", "vim.o.ignorecase = not vim.o.ignorecase", {})
    t.assert_eq(before, ui:rpc("nvim_exec_lua", "return winbar_probe.renders", {}), "unrelated options do not redraw")
  end
end)

t:test("failed initial open remains closable and refresh retries after the directory appears", function()
  local root = directory()
  local path = root .. "/missing"
  local Widget = require("era.m.explorer.widget")
  local widget = Widget.new({ name = "failed-open", root = path })
  t:defer(function()
    widget:dispose()
  end)
  widget:focus()
  t.wait_until(function()
    return widget._ready:is_failed()
  end, 10000)
  t.assert_true(widget:status_text():find("open failed", 1, true) ~= nil)
  local keys = {}
  for _, value in ipairs(vim.api.nvim_buf_get_keymap(widget:get_bufnr(), "n")) do
    keys[value.lhs] = true
  end
  t.assert_true(keys.q and keys.R)
  assert(vim.uv.fs_mkdir(path, 448))
  write(path .. "/file")
  await(widget:refresh())
  t.wait_until(function()
    local view = widget._views[vim.api.nvim_get_current_tabpage()]
    return view and view:frame() and view:frame():header().row_count == 1
  end, 10000)
  t.assert_true(widget._open_error == nil)
end)

t:test("replacing an Explorer buffer releases its window and late cleanup preserves the reopened pane", function()
  local path = directory()
  write(path .. "/a")
  local widget = fixture.widget(path)
  local _, view = widget:context()
  local winnr = view.winnr
  local bufnr = vim.api.nvim_create_buf(true, false)
  t:defer(function()
    if vim.api.nvim_win_is_valid(winnr) then
      vim.api.nvim_win_close(winnr, true)
    end
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end)
  vim.api.nvim_win_set_buf(winnr, bufnr)
  vim.api.nvim_set_option_value("winbar", "other owner", { win = winnr })
  vim.api.nvim_set_option_value("winhighlight", "Normal:Normal", { win = winnr })
  vim.api.nvim_set_option_value("cursorline", false, { win = winnr })
  local width = vim.api.nvim_win_get_width(winnr)
  widget:toggle_flag(4)
  widget:render_winbar()
  widget:set_width(width + 5)
  t.assert_eq("other owner", vim.api.nvim_get_option_value("winbar", { win = winnr }))
  t.assert_eq("Normal:Normal", vim.api.nvim_get_option_value("winhighlight", { win = winnr }))
  t.assert_false(vim.api.nvim_get_option_value("cursorline", { win = winnr }))
  t.assert_eq(width, vim.api.nvim_win_get_width(winnr))
  t.assert_false(widget:isvisible())
  widget:hide()
  t.assert_true(vim.api.nvim_win_is_valid(winnr))
  t.assert_eq(bufnr, vim.api.nvim_win_get_buf(winnr))

  local reopened = widget:focus()
  t.assert_true(reopened ~= winnr)
  t.wait_until(function()
    local current = widget._views[vim.api.nvim_get_current_tabpage()]
    return current and current:frame()
  end, 10000)
  view:detach()
  vim.api.nvim_win_close(winnr, true)
  t.assert_eq(reopened, widget:get_winnr())
  local _, current = widget:context()
  t.assert_true(current:frame() ~= nil)
  t.assert_eq(reopened, current.winnr)
end)

t:test("a replaced loading placeholder cannot be claimed by a late attach", function()
  local Session = require("era.m.explorer.session")
  local Widget = require("era.m.explorer.widget")
  local open = Session.open
  local pending, resolve = stl.c.Future.new_with_resolver()
  local opening, session
  t:defer(function()
    if session then
      session:dispose()
    end
  end)
  t:patch_table(Session, "open", function(...)
    opening = open(...)
    return pending
  end)
  local path = directory()
  write(path .. "/a")
  local widget = Widget.new({ name = "pending-owner", root = path })
  t:defer(function()
    widget:dispose()
  end)
  local winnr = widget:focus()
  local bufnr = vim.api.nvim_create_buf(true, false)
  t:defer(function()
    if vim.api.nvim_win_is_valid(winnr) then
      vim.api.nvim_win_close(winnr, true)
    end
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end)
  session = await(opening)
  vim.api.nvim_win_set_buf(winnr, bufnr)
  vim.api.nvim_set_option_value("winbar", "loading replacement", { win = winnr })
  widget:render_winbar()
  t.assert_false(widget:isvisible())
  widget:hide()
  t.assert_true(vim.api.nvim_win_is_valid(winnr))
  local reopened = widget:focus()
  resolve(session)
  t.wait_until(function()
    local view = widget._views[vim.api.nvim_get_current_tabpage()]
    return view and view:frame()
  end, 10000)
  t.assert_eq(bufnr, vim.api.nvim_win_get_buf(winnr))
  t.assert_eq("loading replacement", vim.api.nvim_get_option_value("winbar", { win = winnr }))
  vim.api.nvim_win_close(winnr, true)
  t.assert_eq(reopened, widget:get_winnr())
  t.assert_eq(session, widget:context())
end)

t:run()
