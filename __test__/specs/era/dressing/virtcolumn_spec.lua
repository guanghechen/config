local harness = require("__test__.support.harness")
local Grid = require("__test__.support.ui_grid")
local UI = require("__test__.support.ui")

local t = harness.new()

local GUIDE = "╎" ---@type string

-- A child Nvim with a UI and only this module loaded; `drawn` collects the rows each redraw draws.
---@return __test__.support.UI ui
---@return table grid
local function start()
  local ui = UI.open(t)
  local grid = Grid.new(ui)
  ui:start({ width = 130, height = 12 })
  ui:lua([=[
    vim.o.wrap = false
    local enabled = true
    local observers = {}
    stl = {
      filetype = require("stl.filetype"),
      fn = {
        observe = function(_, callback)
          observers[#observers + 1] = callback
        end,
      },
    }
    dot = {
      context = { flight = { dressing_virtcolumn = { snapshot = function() return enabled end } } },
      var = { nsnr = { virtcolumn = vim.api.nvim_create_namespace("ux:virtcolumn") } },
    }
    function set_enabled(value)
      enabled = value
      for _, callback in ipairs(observers) do
        callback()
      end
    end
    drawn = {}
    vim.api.nvim_set_decoration_provider(vim.api.nvim_create_namespace("probe"), {
      on_line = function(_, _, _, row)
        drawn[#drawn + 1] = row
      end,
    })
    local virtcolumn = require("era.dressing.virtcolumn")
    virtcolumn.dressing()
    virtcolumn.dressing()
    observer_count = #observers
    vim.api.nvim_buf_set_lines(0, 0, -1, false, {
      "short", ("x"):rep(99), ("x"):rep(100), ("x"):rep(119), ("x"):rep(120),
    })
    vim.bo.filetype = "lua"
    vim.cmd("redraw!")
  ]=])
  return ui, grid
end

---@param grid                          table
---@param row                           integer
---@param col                           integer
---@return string
local function cell(grid, row, col)
  return grid.grids[1].rows[row + 1][col][1]
end

t:test("guides mark the columns a line leaves free and persist nothing", function()
  local ui, grid = start()

  t.assert_eq(GUIDE, cell(grid, 0, 100), "short line, first column")
  t.assert_eq(GUIDE, cell(grid, 0, 120), "short line, second column")
  t.assert_eq(GUIDE, cell(grid, 1, 100), "99 characters leave column 100 free")
  t.assert_eq("x", cell(grid, 2, 100), "100 characters cover column 100")
  t.assert_eq(GUIDE, cell(grid, 2, 120), "100 characters leave column 120 free")
  t.assert_eq(GUIDE, cell(grid, 3, 120), "119 characters leave column 120 free")
  t.assert_eq("x", cell(grid, 4, 120), "120 characters cover column 120")
  t.assert_eq(0, ui:lua("return #vim.api.nvim_buf_get_extmarks(0, dot.var.nsnr.virtcolumn, 0, -1, {})"), "extmarks")
  t.assert_eq(1, ui:lua("return observer_count"), "dressing initializes once")
end)

t:test("guides follow horizontal scrolling", function()
  local ui, grid = start()
  ui:lua([[vim.api.nvim_win_set_cursor(0, { 5, 60 }); vim.fn.winrestview({ leftcol = 10 }); vim.cmd("redraw")]])
  t.assert_eq(10, ui:lua("return vim.fn.winsaveview().leftcol"), "scrolled")

  t.assert_eq(GUIDE, cell(grid, 0, 90), "first column shifts left")
  t.assert_eq(GUIDE, cell(grid, 2, 110), "second column shifts left")
  t.assert_true(cell(grid, 0, 100) ~= GUIDE, "nothing left at the unscrolled column")
end)

t:test("an edit redraws only the edited line, which is measured again", function()
  local ui, grid = start()
  local drawn = ui:lua([[
    drawn = {}
    vim.api.nvim_buf_set_text(0, 0, 5, 0, 5, { ("y"):rep(95) })
    vim.cmd("redraw")
    return drawn
  ]])

  t.assert_same({ 0 }, drawn, "rows drawn after the edit")
  t.assert_eq("y", cell(grid, 0, 100), "the lengthened line covers column 100")
  t.assert_eq(GUIDE, cell(grid, 0, 120), "column 120 stays free")
  -- A deferred refresh would repaint other rows later, once the child is back at its main loop.
  vim.wait(100)
  t.assert_same({ 0 }, ui:lua([[vim.cmd("redraw"); return drawn]]), "rows drawn once the edit settles")
end)

t:test("tabs and wide characters are measured in display cells", function()
  local ui, grid = start()
  ui:lua([[
    vim.bo.tabstop = 2
    vim.bo.eol, vim.bo.fixeol = false, false
    vim.api.nvim_buf_set_lines(0, 0, -1, false, {
      ("\t"):rep(30) .. ("x"):rep(50),
      "-- " .. ("中"):rep(40),
      ("x"):rep(100),
    })
    vim.cmd("redraw!")
  ]])

  t.assert_eq("x", cell(grid, 0, 100), "80 bytes of tabs and text cover column 100 with 110 cells")
  t.assert_eq(GUIDE, cell(grid, 0, 120), "110 cells leave column 120 free")
  t.assert_eq(GUIDE, cell(grid, 1, 100), "123 bytes of wide characters leave column 100 free in 83 cells")
  t.assert_eq(GUIDE, cell(grid, 1, 120), "and column 120")
  t.assert_eq("x", cell(grid, 2, 100), "a last line without an end of line still covers column 100")
end)

t:test("disabled filetypes and the flight switch draw no guides", function()
  local ui, grid = start()

  ui:lua([[vim.bo.filetype = stl.filetype.EXPLORER; vim.cmd("redraw!")]])
  t.assert_true(cell(grid, 0, 100) ~= GUIDE, "disabled filetype")
  ui:lua([[vim.bo.filetype = "lua"; vim.cmd("redraw!")]])
  t.assert_eq(GUIDE, cell(grid, 0, 100), "eligible filetype")

  ui:lua([[set_enabled(false); vim.cmd("redraw")]])
  t.assert_true(cell(grid, 0, 100) ~= GUIDE, "switched off")
  ui:lua([[set_enabled(true); vim.cmd("redraw")]])
  t.assert_eq(GUIDE, cell(grid, 0, 100), "switched on")
end)

t:test("floating windows draw guides only while focused", function()
  local ui, grid = start()
  ui:lua([[
    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "float" })
    float = vim.api.nvim_open_win(bufnr, false, {
      relative = "editor", row = 7, col = 0, width = 125, height = 1, style = "minimal",
    })
    vim.cmd("redraw!")
  ]])
  t.assert_eq("f", cell(grid, 7, 1), "float shown")
  t.assert_true(cell(grid, 7, 100) ~= GUIDE, "unfocused float")

  ui:lua([[vim.api.nvim_set_current_win(float); vim.cmd("redraw!")]])
  t.assert_eq(GUIDE, cell(grid, 7, 100), "focused float")
end)

t:run()
