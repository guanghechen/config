local neotree_width = 0 ---@type integer

local function get_pane_width()
  for _, winnr in pairs(vim.api.nvim_tabpage_list_wins(0)) do
    local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type number
    if vim.bo[bufnr].ft == fml.constant.FT_NEOTREE then
      if not fml.api.win.is_floating(winnr) then
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
  will_change = function(context, prev_context, remain_width)
    local width = math.min(remain_width, get_pane_width()) ---@type integer
    if width ~= neotree_width then
      neotree_width = width
      return true
    end
    return false
  end,
  ---@diagnostic disable-next-line: unused-local
  render = function(context, remain_width)
    local width = math.min(remain_width, neotree_width)
    if width <= 0 then
      return "", 0
    end

    local text = " Explorer"
    local text_width = vim.fn.strwidth(text)
    local left_width = math.floor((width - text_width) / 2)
    local right_width = width - left_width - text_width
    local left_blank = string.rep(" ", left_width)
    local right_blank = string.rep(" ", right_width)

    local hl_text = fml.nvimbar.txt(left_blank, "f_tl_neotree_blank")
      .. fml.nvimbar.txt(text, "f_tl_neotree_text")
      .. fml.nvimbar.txt(right_blank, "f_tl_neotree_blank")
    return hl_text, width + 1
  end,
}

return M
