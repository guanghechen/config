--- Run with: nvim -l __test__/run.lua __test__/specs/era/m/wk/view_spec.lua
---@diagnostic disable: undefined-global

local harness = require("__test__.support.harness")
require("ark.bootstrap").setup()

local View = require("era.m.wk.view")
local t = harness.new("era.m.wk.view")

---@param winnr                         integer
---@param bufnr                         integer
---@return nil
local function register_popup(winnr, bufnr)
  ---@diagnostic disable-next-line: invisible
  t:defer(function()
    if vim.api.nvim_win_is_valid(winnr) then
      vim.api.nvim_win_close(winnr, true)
    end
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end)
end

t:test("popup is compact and anchored to the bottom right", function()
  local layout = View.__layout__({
    { key = "a", desc = "alpha", is_group = false },
    { key = "b", desc = "beta", is_group = true },
  })
  local winnr, bufnr = View.__create_win__(layout)
  register_popup(winnr, bufnr)

  local config = vim.api.nvim_win_get_config(winnr)
  t.assert_true(config.width < vim.o.columns, "compact width")
  t.assert_eq(vim.o.columns - 1, config.col + config.width, "right edge")
  t.assert_eq(vim.o.lines - vim.o.cmdheight - 1, config.row + config.height, "bottom edge")
  t.assert_eq(15, vim.api.nvim_get_option_value("winblend", { win = winnr }), "popup transparency")
  t.assert_false(vim.api.nvim_get_option_value("wrap", { win = winnr }), "popup wrap")
end)

t:test("layout caps wide menus while preserving multiple columns", function()
  local items = {} ---@type era.m.wk.IViewItem[]
  for index = 1, 12 do
    items[index] = {
      key = tostring(index),
      desc = "action " .. tostring(index),
      is_group = false,
    }
  end

  local layout = View.__layout__(items)
  t.assert_true(layout.cols > 1, "multiple columns")
  t.assert_true(layout.content_width + 4 <= math.min(100, vim.o.columns - 1), "bounded content width")
end)

t:test("layout includes the separator after an icon", function()
  local layout = View.__layout__({
    { key = "a", desc = string.rep("x", 30), icon = "*", is_group = false },
  })

  t.assert_eq(36, layout.content_width, "content width")
end)

t:run()
