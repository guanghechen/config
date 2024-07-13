---@type fml.types.ui.nvimbar.IRawComponent
local M = {
  name = "indicator",
  ---@diagnostic disable-next-line: unused-local
  render = function(context, remain_width)
    local winnr_cur = fml.api.state.get_current_tab_winnr() ---@type integer
    local text = winnr_cur == context.winnr and "▎" or " "
    local width = #text
    local hl_text = fml.nvimbar.txt(text, "f_wl_indicator")
    return hl_text, width
  end,
}

return M
