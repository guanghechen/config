---@type t.fml.ux.nvimbar.IRawComponent
local M = {
  name = "indicator",
  ---@diagnostic disable-next-line: unused-local
  render = function(context, remain_width)
    local winnr_cur = fml.api.tab.get_current_winnr() ---@type integer
    local text = winnr_cur == context.winnr and eve.icons.symbols.win_indicator_active
      or eve.icons.symbols.win_indicator
    local hl_text = eve.nvimbar.txt(text, "f_wl_indicator")
    local width = vim.api.nvim_strwidth(text) ---@type integer
    return hl_text, width
  end,
}

return M
