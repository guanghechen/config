---@return integer
---@return integer
---@return string
local function calc_row_percentage()
  local total_lines = vim.fn.line("$")
  local cursor = vim.api.nvim_win_get_cursor(0)
  local row = cursor[1] ---@type integer
  local col = cursor[2] + 1 ---@type integer

  if row == 1 then
    return row, col, "Top"
  elseif row == total_lines then
    return row, col, "Bot"
  else
    return row, col, eve.string.pad_start(tostring(math.floor(100 * row / total_lines)), 2, " ") .. "%"
  end
end

---@type fml.types.ui.nvimbar.IRawComponent
local M = {
  name = "pos",
  render = function()
    local row, col, percentage = calc_row_percentage() ---@type integer, integer, string
    local text_anchor = "" .. row .. "·" .. col .. " " ---@type string
    local text_pos = " " .. percentage .. " " ---@type string
    local hl_text = eve.nvimbar.txt(text_anchor, "f_sl_text") .. eve.nvimbar.txt(text_pos, "f_sl_pos") ---@type string
    local width = vim.fn.strwidth(text_anchor .. text_pos) ---@type integer
    return hl_text, width
  end,
}

return M
