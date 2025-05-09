local txt = eve.nvim.txt

---@param filetype                      string
---@return integer
local function get_pane_width(filetype)
  local winnrs = vim.api.nvim_tabpage_list_wins(0) ---@type integer[]
  for _, winnr in ipairs(winnrs) do
    local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
    if vim.bo[bufnr].filetype == filetype then
      if not eve.win.is_float(winnr) then
        return vim.api.nvim_win_get_width(winnr)
      end
    end
  end
  return 0
end

---@class eve.ux.nvimbar.component.sidebar
local M = {}

---@param position                      eve.ux.nvimbar.PositionEnum
---@param filetype                      string
---@param get_title                     fun(context: eve.ux.nvimbar.INvimbarContext): string
---@return eve.ux.nvimbar.IRawComponent
function M.of(position, filetype, get_title)
  local hln_blank = position .. "_sidebar_blank" ---@type string
  local hln_split = position .. "_sidebar_split" ---@type string
  local hln_sep = "ms_b_none" ---@type string
  local hln_text = "mf_b_bg0" ---@type string

  ---@type eve.ux.nvimbar.IRawComponent
  local component = {
    name = "sidebar:of:" .. filetype,
    atomic = true,
    render = function(context, remain_width)
      local width = math.min(remain_width, get_pane_width(filetype)) ---@type integer
      if width < 1 then
        return "", "", true
      end

      local title = get_title(context) ---@type string
      if width < #title + 4 then
        local text = string.rep(" ", width) ---@type string
        local hl_text = txt(text, hln_blank)
        return text, hl_text, true
      end

      local text_title = title ---@type string
      local hl_text_title = txt(text_title, hln_text) ---@type string

      text_title = eve.icon.symbols.sep_left .. text_title ---@type string
      hl_text_title = txt(eve.icon.symbols.sep_left, hln_sep) .. hl_text_title ---@type string

      text_title = text_title .. eve.icon.symbols.sep_right ---@type string
      hl_text_title = hl_text_title .. txt(eve.icon.symbols.sep_right, hln_sep) ---@type string

      local title_width = vim.api.nvim_strwidth(text_title) ---@type integer
      local width_remain = width - title_width ---@type integer
      local left_width = math.floor(width_remain / 2) ---@type integer
      local right_width = width_remain - left_width - 1 ---@type integer
      local left_blank = string.rep(" ", left_width) ---@type string
      local right_blank = string.rep(" ", right_width) ---@type string
      local right_split = " " ---@type string -- "│"

      local text = left_blank .. text_title .. right_blank .. right_split ---@type string
      local hl_text = txt(left_blank, hln_blank)
        .. hl_text_title
        .. txt(right_blank, hln_blank)
        .. txt(right_split, hln_split)
      return text, hl_text, true
    end,
  }
  return component
end

return M
