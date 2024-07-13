---@type fml.types.ui.nvimbar.IRawComponent
local M = {
  name = "indicator",
  ---@diagnostic disable-next-line: unused-local
  render = function(context, remain_width)
    local winnr = vim.api.nvim_get_current_win() ---@type integer
    local text = winnr == context.winnr and "▎" or " "
    local width = #text
    local hl_text = fml.nvimbar.txt(text, "f_wl_indicator")
    return hl_text, width
  end,
}

return M
