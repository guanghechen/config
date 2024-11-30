---@type fml.t.ux.nvimbar.IRawComponent
local M = {
  name = "indicator",
  ---@diagnostic disable-next-line: unused-local
  render = function(context, remain_width)
    local winnr_cur = eve.locations.get_current_winnr() or 0 ---@type integer
    local activated = winnr_cur == context.winnr ---@type boolean
    local text = activated and eve.icons.symbols.win_indicator_active or eve.icons.symbols.win_indicator ---@type string
    local hln_text = activated and "f_wla_indicator" or "f_wl_indicator" ---@type string

    local hl_text = eve.nvim.txt(text, hln_text)
    local width = vim.api.nvim_strwidth(text) ---@type integer
    return hl_text, width
  end,
}

return M
