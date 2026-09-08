---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.nvimbar.component.sidebar" ---@type string

local txt = stl.nvim.fn.txt

---@param filetype                      string
---@param tabnr                         integer
---@return integer|nil
local function get_pane_winnr(filetype, tabnr)
  local winnrs = vim.api.nvim_tabpage_list_wins(tabnr) ---@type integer[]
  for _, winnr in ipairs(winnrs) do
    local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
    if vim.api.nvim_get_option_value("filetype", { buf = bufnr }) == filetype then
      if not stl.nvim.win.is_float(winnr) then
        return winnr
      end
    end
  end
  return nil
end

---@class era.m.nvimbar.component.sidebar
local M = {}

---@param position                      stl.t.NvimbarPositionEnum
---@param filetype                      string
---@param get_title                     fun(context: era.m.nvimbar.INvimbarContext): string
---@return era.m.nvimbar.IRawComponent
function M.of(position, filetype, get_title)
  local hln_blank = position .. "_sidebar_blank" ---@type string
  local hln_split = position .. "_sidebar_split" ---@type string
  local hln_sep = "ms_b_none" ---@type string
  local hln_text = "mf_b_bg0" ---@type string

  ---@type era.m.nvimbar.IRawComponent
  local component = {
    name = "sidebar:of:" .. filetype,

    refresh = function(context)
      return { winnr = get_pane_winnr(filetype, context.tabnr), title = get_title(context) }
    end,
    render = function(snapshot, context, remain_width)
      local winnr = snapshot.winnr
      if
        winnr == nil
        or not vim.api.nvim_win_is_valid(winnr)
        or vim.api.nvim_win_get_tabpage(winnr) ~= context.tabnr
      then
        return "", ""
      end
      local width = math.min(remain_width, vim.api.nvim_win_get_width(winnr)) ---@type integer
      if width < 1 then
        return "", ""
      end

      local title = snapshot.title ---@type string
      if width < #title + 4 then
        local text = string.rep(" ", width) ---@type string
        local hl_text = txt(text, hln_blank)
        return text, hl_text
      end

      local text_title = title ---@type string
      local hl_text_title = txt(text_title, hln_text) ---@type string

      text_title = stl.icon.symbols.sep_left .. text_title ---@type string
      hl_text_title = txt(stl.icon.symbols.sep_left, hln_sep) .. hl_text_title ---@type string

      text_title = text_title .. stl.icon.symbols.sep_right ---@type string
      hl_text_title = hl_text_title .. txt(stl.icon.symbols.sep_right, hln_sep) ---@type string

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
      return text, hl_text
    end,
  }
  return component
end

return M
