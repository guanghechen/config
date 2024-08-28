---@return string
local function calc_row_percentage()
  local current_line = vim.fn.line(".")
  local total_lines = vim.fn.line("$")

  if current_line == 1 then
    return "Top"
  elseif current_line == total_lines then
    return "Bot"
  else
    return fml.string.pad_start(tostring(math.floor(100 * current_line / total_lines)), 2, " ") .. "%%"
  end
end

---@type fml.types.ui.nvimbar.IRawComponent
local M = {
  name = "pos",
  render = function()
    local text_anchor = "%l·%c " ---@type string
    local text_pos = " " .. calc_row_percentage() .. " " ---@type string
    local hl_text = fml.nvimbar.txt(text_anchor, "f_sl_text") .. fml.nvimbar.txt(text_pos, "f_sl_pos") ---@type string
    local width = vim.fn.strwidth(text_anchor .. text_pos) ---@type integer
    return hl_text, width
  end,
}

return M
