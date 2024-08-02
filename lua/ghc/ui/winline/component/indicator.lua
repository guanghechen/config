---@type fml.ui.icons.symbols
local symbols = fml.ui.icons.symbols

---@type fml.types.ui.nvimbar.IRawComponent
local M = {
  name = "indicator",
  ---@diagnostic disable-next-line: unused-local
  render = function(context, remain_width)
    local winnr_cur = fml.api.state.get_current_tab_winnr() ---@type integer
    local text = winnr_cur == context.winnr and symbols.win_indicator_active or symbols.win_indicator
    local hl_text = fml.nvimbar.txt(text, "f_wl_indicator")
    local width = vim.fn.strwidth(text) ---@type integer
    return hl_text, width
  end,
}

return M
