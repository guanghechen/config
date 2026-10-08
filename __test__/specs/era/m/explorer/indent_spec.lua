---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.specs.era.m.explorer.indent" ---@type string

local t = require("__test__.support.harness").new("era.m.explorer.indent")

t:test("guides stay visible through Visual selection and clip correctly when scrolled", function()
  local path = vim.fn.tempname()
  vim.fn.mkdir(path .. "/branch", "p")
  local long_name = "b-long-child-for-horizontal-scroll.lua"
  for _, name in ipairs({ "branch/a.lua", "branch/" .. long_name, "z.lua" }) do
    vim.fn.writefile({ "content" }, path .. "/" .. name)
  end
  local ui = require("__test__.support.ui").new()
  local grid = require("__test__.support.ui_grid").new(ui)
  t:defer(function()
    ui:close()
    vim.fn.delete(path, "rf")
  end)
  ui:rpc("nvim_ui_attach", 100, 30, { rgb = true, ext_linegrid = true })
  ui:rpc(
    "nvim_exec_lua",
    [=[
    local root, path = ...
    vim.opt.runtimepath:prepend(root)
    local system = vim.uv.os_uname().sysname
    local library = system == "Windows_NT" and "yoz.dll" or (system == "Darwin" and "libyoz.dylib" or "libyoz.so")
    yoz = assert(package.loadlib(root .. "/rust/target/debug/" .. library, "luaopen_yoz"))()
    stl, dot, era = require("stl"), require("dot"), require("era")
    dot.path.workspace = function() return path end
    dot.path.is_git_repo = function() return false end
    errors = {}
    stl.reporter.warn = function(value) errors[#errors + 1] = value.message end
    stl.reporter.error = stl.reporter.warn
    stl.reporter.info = function() end
    widget = require("era.m.explorer.widget").new({
      name = "indent-visual", root = path,
      o_flag_foldempty = stl.c.Observable.from_value(false),
    })
    widget:focus()
    local future = widget:reveal(path .. "/branch/a.lua")
    assert(vim.wait(10000, function() return future:is_done() end))
    assert(not future:is_failed(), future:get_error())
    session, view = widget:context()
    assert(vim.wait(10000, function()
      return view:frame() and view:frame():header().row_count == 4
        and not session.data._native:is_busy() and session.state._native:applicable(view:frame())
    end))
  ]=],
    { assert(vim.uv.cwd()), path }
  )

  ---@param label                       string
  ---@return nil
  local function visible_guides(label)
    ui:rpc("nvim_command", "redraw!")
    local location = assert(grid:find("a.lua"), label .. ": missing filename")
    local cells = grid.grids[location.grid].rows[location.row + 1]
    local guides = {}
    for col = 1, location.col do
      local cell = cells[col]
      if cell[1] == "│" or cell[1] == "├" or cell[1] == "─" then
        guides[#guides + 1] = cell[1]
        local highlight = grid.highlights[cell[2]]
        t.assert_true(highlight.foreground ~= highlight.background, label .. ": guide blends into its background")
      end
    end
    t.assert_eq("│├─", table.concat(guides), label .. ": structural guides disappeared")
  end

  for _, theme in ipairs({ "rosepine-dawn", "rosepine-main", "vsc-light-modern", "vsc-dark-modern" }) do
    ui:rpc("nvim_exec_lua", "dot.context.theme.apply_theme({ theme = ..., transparency = false })", { theme })
    for _, input in ipairs({ { "Vj", "V" }, { "vj", "v" }, { "v<C-v>j3l", vim.keycode("<C-v>") } }) do
      ui:rpc("nvim_exec_lua", "vim.api.nvim_win_set_cursor(view.winnr, {2, 0})", {})
      visible_guides(theme .. " Normal")
      ui:rpc("nvim_input", input[1])
      t.wait_until(function()
        return ui:rpc("nvim_exec_lua", "return vim.api.nvim_get_mode().mode == ...", { input[2] })
      end, 10000)
      visible_guides(theme .. " " .. input[2])
      ui:rpc("nvim_input", "<Esc>")
      t.wait_until(function()
        return ui:rpc("nvim_exec_lua", "return vim.api.nvim_get_mode().mode:sub(1, 1) == 'n'", {})
      end, 10000)
      visible_guides(theme .. " after Visual")
    end
    local foreground =
      ui:rpc("nvim_exec_lua", "return vim.api.nvim_get_hl(0, { name = 'm_ex_indent', link = false }).fg", {})
    ui:rpc("nvim_exec_lua", "vim.api.nvim_win_set_cursor(view.winnr, {4, 0})", {})
    ui:rpc("nvim_command", "redraw!")
    local location = assert(grid:find("a.lua"))
    local cells = grid.grids[location.grid].rows[location.row + 1]
    for col = 1, location.col do
      if cells[col][1] == "│" or cells[col][1] == "├" or cells[col][1] == "─" then
        t.assert_eq(
          foreground,
          grid.highlights[cells[col][2]].foreground,
          theme .. ": ordinary guides keep their muted color"
        )
      end
    end
  end
  ui:rpc(
    "nvim_exec_lua",
    [=[
    local future = session.state:dispatch({ kind = "set_cursor", node = view:frame():node_at(3) })
    assert(vim.wait(10000, function() return future:is_done() end))
    assert(vim.wait(10000, function()
      return view:frame():header().cursor_row == 3 and not view._busy and not view._latest
    end))
  ]=],
    {}
  )
  ui:rpc(
    "nvim_exec_lua",
    [=[
    vim.api.nvim_win_set_cursor(view.winnr, {3, 23})
    vim.api.nvim_win_call(view.winnr, function() vim.cmd("normal! zs") end)
  ]=],
    {}
  )
  ui:rpc("nvim_command", "redraw!")
  local tail = assert(grid:find("scroll.lua"))
  local cells = grid.grids[tail.grid].rows[tail.row + 1]
  for col = 1, tail.col do
    t.assert_false(
      vim.tbl_contains({ "│", "╰", "├", "─" }, cells[col][1]),
      "a clipped guide covers the filename"
    )
  end
  t.assert_eq(0, ui:rpc("nvim_exec_lua", "return #errors", {}))
  ui:rpc("nvim_exec_lua", "widget:dispose()", {})
end)

t:run()
