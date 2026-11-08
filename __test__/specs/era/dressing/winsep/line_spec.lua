local harness = require("__test__.support.harness")
require("ark.bootstrap").setup()

local t = harness.new()
local Line = require("era.dressing.winsep.line")

---@param line                          era.dressing.winsep.Line
---@return integer|nil
local function tab_of(line)
  local winnr = line._winnr
  return winnr ~= nil and vim.api.nvim_win_is_valid(winnr) and vim.api.nvim_win_get_tabpage(winnr) or nil
end

t:test("a line shown in another tab opens there and leaves the tab it was in", function()
  local first = vim.api.nvim_get_current_tabpage()
  local line = Line.new({ direction = "l" })
  t:defer(function()
    line:hide()
  end)
  line:move(0, 10, 3)
  line:show()
  t.assert_eq(first, tab_of(line), "the first tab")

  vim.cmd("tabnew")
  local second = vim.api.nvim_get_current_tabpage()
  t:defer(function()
    if vim.api.nvim_tabpage_is_valid(second) then
      vim.cmd("tabclose " .. vim.api.nvim_tabpage_get_number(second))
    end
  end)
  line:move(0, 20, 3)
  line:show()
  t.assert_eq(second, tab_of(line), "the second tab")
  t.assert_same(
    { "╮", "│", "│", "│", "╯" },
    vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(line._winnr), 0, -1, false)
  )
  for _, winnr in ipairs(vim.api.nvim_tabpage_list_wins(first)) do
    t.assert_true(vim.api.nvim_win_get_config(winnr).relative == "", "no line left in the first tab")
  end
end)

t:run()
