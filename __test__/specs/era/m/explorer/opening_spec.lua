---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.specs.era.m.explorer.opening" ---@type string

local fixture = require("__test__.support.explorer").new("era.m.explorer.opening")
local Widget = require("era.m.explorer.widget")
local Session = require("era.m.explorer.session")
local t = fixture.t

t:test("one failed opening reports once across views, display changes and reveal; each retry reports once", function()
  local reports = {}
  t:patch_table(stl.reporter, "warn", function(value)
    reports[#reports + 1] = value.message
  end)
  local path = fixture.directory() .. "/missing"
  local widget = Widget.new({ name = "opening-reports", root = path })
  t:defer(function()
    widget:dispose()
  end)
  widget:focus()
  widget:toggle_flag(4)
  widget:reveal(path .. "/file")
  vim.cmd.tabnew()
  local tabnr = vim.api.nvim_get_current_tabpage()
  t:defer(function()
    if vim.api.nvim_tabpage_is_valid(tabnr) then
      vim.api.nvim_set_current_tabpage(tabnr)
      vim.cmd("tabclose!")
    end
  end)
  widget:focus()
  t.wait_until(function()
    return widget._ready:is_failed() and not widget._display_scheduled
  end, 10000)
  t.assert_eq(1, #reports)
  t.assert_true(reports[1]:find("NotFound", 1, true) ~= nil)
  t.assert_true(reports[1]:find("R in Explorer", 1, true) ~= nil)
  t.assert_true(reports[1]:find("stack traceback", 1, true) == nil)
  t.assert_true(
    widget._ready:get_error():find("stack traceback", 1, true) ~= nil,
    "the Future retains diagnostic detail"
  )

  local previous = widget._ready
  vim.api.nvim_feedkeys("R", "xt", false)
  t.wait_until(function()
    return widget._ready ~= previous and widget._ready:is_failed()
  end, 10000)
  t.assert_eq(2, #reports)
  assert(vim.uv.fs_mkdir(path, 448))
  fixture.write(path .. "/file")
  fixture.await(widget:refresh())
  t.wait_until(function()
    local view = widget._views[tabnr]
    return view and view:frame() and view:frame():header().row_count == 1
  end, 10000)
  t.assert_eq(2, #reports)
  t.assert_eq(nil, widget._open_error)
end)

t:test("late opening failures cannot report or reclaim a newer opening or disposed widget", function()
  for _, dispose in ipairs({ false, true }) do
    local reports = {}
    t:patch_table(stl.reporter, "warn", function(value)
      reports[#reports + 1] = value.message
    end)
    local reject
    local pending = stl.c.Future.new(function(_, fail)
      reject = fail
    end)
    local open = Session.open
    local first = true
    local restore = t:patch_table(Session, "open", function(...)
      if first then
        first = false
        return pending
      end
      return open(...)
    end)
    local path = fixture.directory()
    fixture.write(path .. "/file")
    local widget = Widget.new({ name = "obsolete-opening-" .. tostring(dispose), root = path })
    t:defer(function()
      widget:dispose()
    end)
    widget:focus()
    if dispose then
      widget:dispose()
    else
      fixture.await(widget:set_root(path))
      t.wait_until(function()
        local view = widget._views[vim.api.nvim_get_current_tabpage()]
        return view and view:frame()
      end, 10000)
    end
    reject("ProviderError: obsolete opening")
    t.assert_eq(0, #reports)
    t.assert_eq(nil, widget._open_error)
    if not dispose then
      t.assert_true(widget:context() ~= nil)
    end
    restore()
  end
end)

t:test("a view attachment failure after a successful opening still reports", function()
  local reports = {}
  t:patch_table(stl.reporter, "warn", function(value)
    reports[#reports + 1] = value.message
  end)
  local path = fixture.directory()
  fixture.write(path .. "/file")
  local widget = Widget.new({ name = "attachment-error", root = path })
  t:defer(function()
    widget:dispose()
  end)
  fixture.await(widget._ready)
  t:patch_table(require("ux.filetree"), "attach", function()
    error("attachment failed", 0)
  end)
  widget:focus()
  t.assert_eq(1, #reports)
  t.assert_true(reports[1]:find("attachment failed", 1, true) ~= nil)
  t.assert_eq(nil, widget._open_error)
end)

t:run()
