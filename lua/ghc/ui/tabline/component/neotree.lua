local symbols = fml.ui.icons.symbols ---@type fml.ui.icons.symbols
local indicator_symbol_width = vim.fn.strwidth(symbols.win_indicator_active) ---@type integer

---@return integer
local function get_pane_width()
  for _, winnr in pairs(vim.api.nvim_tabpage_list_wins(0)) do
    local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type number
    if vim.bo[bufnr].ft == fml.constant.FT_NEOTREE then
      if not fml.api.state.is_floating_win(winnr) then
        return vim.api.nvim_win_get_width(winnr) + 1
      end
    end
  end
  return 0
end

---@type fml.types.ui.nvimbar.IRawComponent
local M = {
  name = "neotree",
  ---@diagnostic disable-next-line: unused-local
  render = function(context, remain_width)
    local width = math.min(remain_width, get_pane_width()) ---@type integer
    if width <= 20 then
      return "", 0
    end

    local winnr_cur = fml.api.state.get_current_tab_winnr() ---@type integer
    local bufnr_cur = vim.api.nvim_win_get_buf(winnr_cur) ---@type integer
    local is_win_active = vim.bo[bufnr_cur].ft == fml.constant.FT_NEOTREE
    local indicator = is_win_active and symbols.win_indicator_active or symbols.win_indicator

    local text = " Explorer" ---@type string
    local text_width = vim.fn.strwidth(text) ---@type integer
    local text_width_remain = width - text_width - indicator_symbol_width ---@type integer
    local left_width = math.floor(text_width_remain / 2) 
    local right_width = text_width_remain - left_width - 1
    local left_blank = string.rep(" ", left_width)
    local right_blank = string.rep(" ", right_width)
    local right_split = "│"

    local hl_text =
        fml.nvimbar.txt(indicator, "f_wl_indicator")
        .. fml.nvimbar.txt(left_blank, "f_tl_neotree_blank")
        .. fml.nvimbar.txt(text, "f_tl_neotree_text")
        .. fml.nvimbar.txt(right_blank, "f_tl_neotree_blank")
        .. fml.nvimbar.txt(right_split, "f_tl_neotree_split")
    return hl_text, width + 1
  end,
}

return M
