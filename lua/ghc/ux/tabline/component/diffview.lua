local indicator_symbol_width = vim.api.nvim_strwidth(eve.icons.symbols.win_indicator_active) ---@type integer

---@return integer
local function get_pane_width()
  for _, winnr in pairs(vim.api.nvim_tabpage_list_wins(0)) do
    local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type number
    if vim.bo[bufnr].ft == eve.constants.FT_DIFFVIEW_FILES then
      if not eve.win.is_floating(winnr) then
        return vim.api.nvim_win_get_width(winnr) + 1
      end
    end
  end
  return 0
end

---@type t.fml.ux.nvimbar.IRawComponent
local M = {
  name = "diffview",
  ---@diagnostic disable-next-line: unused-local
  render = function(context, remain_width)
    local width = math.min(remain_width, get_pane_width()) ---@type integer
    if width <= 20 then
      return "", 0
    end

    local winnr_cur = fml.api.tab.get_current_winnr() ---@type integer
    local bufnr_cur = vim.api.nvim_win_get_buf(winnr_cur) ---@type integer
    local is_win_active = vim.bo[bufnr_cur].ft == eve.constants.FT_DIFFVIEW_FILES
    local indicator = is_win_active and eve.icons.symbols.win_indicator_active or eve.icons.symbols.win_indicator

    local text = eve.icons.git.Git .. " Git Diffview" ---@type string
    local text_width = vim.api.nvim_strwidth(text) ---@type integer
    local text_width_remain = width - text_width - indicator_symbol_width ---@type integer
    local left_width = math.floor(text_width_remain / 2)
    local right_width = text_width_remain - left_width - 1
    local left_blank = string.rep(" ", left_width)
    local right_blank = string.rep(" ", right_width)
    local right_split = "│"

    local hl_text = eve.nvimbar.txt(indicator, "f_wl_indicator")
      .. eve.nvimbar.txt(left_blank, "f_tl_sidebar_blank")
      .. eve.nvimbar.txt(text, "f_tl_sidebar_text")
      .. eve.nvimbar.txt(right_blank, "f_tl_sidebar_blank")
      .. eve.nvimbar.txt(right_split, "f_tl_sidebar_split")
    return hl_text, width + 1
  end,
}

return M
