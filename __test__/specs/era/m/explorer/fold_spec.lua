---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.specs.era.m.explorer.fold" ---@type string

local t = require("__test__.support.harness").new("era.m.explorer.fold")

t:test("fold keys coexist with which-key and publish names and status together", function()
  local path = vim.fn.tempname()
  vim.fn.mkdir(path .. "/branch/nested", "p")
  for _, name in ipairs({ "keep-a.lua", "keep-b.lua", "branch/inside.lua", "branch/nested/leaf.lua" }) do
    vim.fn.writefile({ "content" }, path .. "/" .. name)
  end
  local ui = require("__test__.support.ui").new()
  t:defer(function()
    ui:close()
    vim.fn.delete(path, "rf")
  end)
  local tracking, failures, observed = false, {}, 0
  local expected = {
    ["branch"] = { color = 0xFFFF00, status = "W:1" },
    ["keep-a.lua"] = { color = 0xFF0000, status = "E:1" },
    ["keep-b.lua"] = { color = 0xFFFF00, status = "W:1" },
    ["inside.lua"] = { color = 0xFFFF00, status = "W:1", optional = true },
    ["nested"] = { color = 0x808080, status = "", optional = true },
    ["leaf.lua"] = { color = 0x808080, status = "", optional = true },
  }
  local grid = require("__test__.support.ui_grid").new(ui, function(screen)
    if not tracking then
      return
    end
    observed = observed + 1
    for name, value in pairs(expected) do
      local cell = screen:find(name)
      if cell then
        local cells = screen.grids[cell.grid].rows[cell.row + 1]
        local line = {}
        for _, item in ipairs(cells) do
          line[#line + 1] = item[1]
        end
        if cell.highlight.foreground ~= value.color or not table.concat(line):find(value.status, 1, true) then
          failures[#failures + 1] = { flush = screen.flushes, name = name, color = cell.highlight.foreground }
        end
      elseif not value.optional then
        failures[#failures + 1] = { flush = screen.flushes, name = name, missing = true }
      end
    end
  end)
  ui:rpc("nvim_ui_attach", 100, 30, { rgb = true, ext_linegrid = true })
  ui:rpc(
    "nvim_exec_lua",
    [=[
    local root, path = ...
    vim.opt.runtimepath:prepend(root)
    local suffix = vim.uv.os_uname().sysname == "Darwin" and "dylib" or "so"
    yoz = assert(package.loadlib(root .. "/rust/target/debug/libyoz." .. suffix, "luaopen_yoz"))()
    stl, dot, era = require("stl"), require("dot"), require("era")
    dot.path.workspace = function() return path end
    dot.path.is_git_repo = function() return false end
    errors = {}
    stl.reporter.warn = function(value) errors[#errors + 1] = value.message end
    stl.reporter.error = stl.reporter.warn
    stl.reporter.info = function() end
    vim.api.nvim_set_hl(0, "DiagnosticError", { fg = 0xFF0000 })
    vim.api.nvim_set_hl(0, "DiagnosticWarn", { fg = 0xFFFF00 })
    vim.api.nvim_set_hl(0, "m_ft_filename", { fg = 0x808080 })
    whichkey = era.dressing.whichkey
    whichkey.state.setup()
    whichkey.state.enable()
    popups, navigations = 0, 0
    local render = whichkey.view.render
    whichkey.view.render = function(...)
      popups = popups + 1
      return render(...)
    end
    local keymaps = require("era.m.explorer.keymaps")
    local bind = keymaps.bind
    keymaps.bind = function(widget, view)
      vim.api.nvim_buf_call(view.bufnr, function()
        whichkey.state.__attach__(view.bufnr)
        assert(vim.fn.maparg("z", "n", false, true).desc == "wk-trigger")
      end)
      bind(widget, view)
    end
    widget = require("era.m.explorer.widget").new({ name = "fold-test", root = path })
    local navigate = widget._action.navigate
    widget._action.navigate = function(self, direction)
      navigations = navigations + 1
      return navigate(self, direction)
    end
    widget:focus()
    assert(vim.wait(10000, function()
      local current = widget._views[vim.api.nvim_get_current_tabpage()]
      return current and current:frame() and current:frame():header().row_count == 3
    end))
    session, view = widget:context()
    for index, name in ipairs({ "keep-a.lua", "keep-b.lua", "branch/inside.lua" }) do
      local counts = index == 1 and { 1, 0, 0, 0 } or { 0, 1, 0, 0 }
      local future = session.data:set_diagnostics(1, index, 1, path .. "/" .. name, counts)
      assert(vim.wait(10000, function() return future:is_done() end))
      assert(not future:is_failed(), future:get_error())
    end
    local on_frame = view._options.on_frame
    view._options.on_frame = function(frame)
      on_frame(frame)
      -- Observers may redraw immediately after a frame is published.
      vim.cmd("redraw")
    end
  ]=],
    { assert(vim.uv.cwd()), path }
  )
  t.wait_until(function()
    for name, value in pairs(expected) do
      local cell = grid:find(name)
      if not value.optional and (not cell or cell.highlight.foreground ~= value.color) then
        return false
      end
    end
    return true
  end, 10000)
  ui:rpc("nvim_input", "[")
  t.wait_until(function()
    return ui:rpc("nvim_exec_lua", "return whichkey.state.keys == '['", {})
  end, 10000, "the prefix must enter which-key before its child is typed")
  ui:rpc("nvim_input", "i")
  t.wait_until(function()
    return ui:rpc("nvim_exec_lua", "return navigations == 1 and not whichkey.state.is_suspended(view.bufnr, 'n')", {})
  end, 10000, "a which-key prefix must execute and restore its triggers")
  t.assert_eq(
    "Explorer: recursive expansion",
    ui:rpc("nvim_exec_lua", "return vim.fn.maparg('z', 'n', false, true).desc", {}),
    "which-key must preserve Explorer's replacement mapping"
  )
  ui:rpc("nvim_exec_lua", "popups = 0", {})
  tracking = true
  for step = 1, 8 do
    local expanded = step % 2 == 1
    local recursive = step > 4
    ui:rpc("nvim_input", recursive and "z" or expanded and "l" or "h")
    t.wait_until(function()
      return ui:rpc(
        "nvim_exec_lua",
        [[
        local expanded, recursive = ...
        local frame = view:frame()
        return frame:header().row_count == (expanded and (recursive and 6 or 5) or 3)
          and frame:rows(1, 1).expanded[1] == expanded
      ]],
        { expanded, recursive }
      )
    end, 10000)
  end
  tracking = false
  t.assert_true(observed >= 8, "fold transitions must reach the UI")
  t.assert_eq(0, #failures, "fold/expand lost decorations: " .. vim.inspect(failures[1]))
  t.assert_eq(0, ui:rpc("nvim_exec_lua", "return popups", {}), "fold keys must not open which-key")
  t.assert_eq(0, ui:rpc("nvim_exec_lua", "return #errors", {}))
  ui:rpc("nvim_exec_lua", "widget:dispose(); whichkey.state.disable()", {})
end)

t:run()
