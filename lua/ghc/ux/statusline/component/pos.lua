---@return integer
---@return integer
---@return string
---@return string
local function calc_row_percentage()
  local total_lines = vim.fn.line("$")
  local cursor = vim.api.nvim_win_get_cursor(0)
  local row = cursor[1] ---@type integer
  local col = cursor[2] + 1 ---@type integer

  if row == 1 then
    return row, col, "top", "f_sl_pos_top"
  elseif row == total_lines then
    return row, col, "bot", "f_sl_pos_bot"
  else
    local text = eve.string.pad_start(tostring(math.floor(100 * row / total_lines)), 2, " ") .. "%" ---@type string
    return row, col, text, "f_sl_pos"
  end
end

---@type t.fml.ux.nvimbar.IRawComponent
local M = {
  name = "pos",
  render = function()
    local row, col, percentage, hl_pos = calc_row_percentage() ---@type integer, integer, string
    local text_anchor = "" .. row .. "·" .. col .. " " ---@type string
    local text_pos = " " .. percentage .. " " ---@type string
    local hl_text = eve.nvimbar.txt(text_anchor, "f_sl_text") .. eve.nvimbar.txt(text_pos, hl_pos) ---@type string
    local width = vim.api.nvim_strwidth(text_anchor .. text_pos) ---@type integer
    return hl_text, width
  end,
}

return M
