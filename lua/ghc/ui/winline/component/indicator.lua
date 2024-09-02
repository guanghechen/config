---@type fml.types.ui.nvimbar.IRawComponent
local M = {
  name = "indicator",
  ---@diagnostic disable-next-line: unused-local
  render = function(context, remain_width)
    local winnr_cur = fml.api.state.get_current_tab_winnr() ---@type integer
    local text = winnr_cur == context.winnr and eve.icons.symbols.win_indicator_active or eve.icons.symbols.win_indicator
    local hl_text = eve.nvimbar.txt(text, "f_wl_indicator")
    local width = vim.fn.strwidth(text) ---@type integer
    return hl_text, width
  end,
}

return M
