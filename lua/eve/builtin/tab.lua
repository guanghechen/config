---@alias eve.builtin.tab.TypeEnum
---| "diffview"
---| "normal"

---@class eve.builtin.tab.Types
local Types = {
  DIFFVIEW = "diffview",
  NORMAL = "normal",
}

---@class eve.builtin.tab
local M = {}

M.Types = Types

---@param tabnr                         integer
---@return eve.builtin.tab.TypeEnum
function M.get_type(tabnr)
  return vim.t[tabnr].eve_type
end

---@param tabnr                         integer
---@param tabtype                       eve.builtin.tab.TypeEnum
---@return nil
function M.set_type(tabnr, tabtype)
  vim.t[tabnr].eve_type = tabtype
end

---@param tabnr                         integer
---@param force                         boolean
---@return eve.builtin.tab.TypeEnum
function M.resolve_type(tabnr, force)
  local tabtype = M.get_type(tabnr) ---@type eve.builtin.tab.TypeEnum|nil
  if tabtype ~= nil and not force then
    return tabtype
  end

  local winnrs = vim.api.nvim_tabpage_list_wins(tabnr) ---@type integer[]

  ---! Check if the diffview tab
  for _, winnr in ipairs(winnrs) do
    local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
    local filetype = vim.bo[bufnr].filetype ---@type string
    if filetype == eve.filetype.DIFFVIEW_FILES or filetype == eve.filetype.DIFFVIEW_FILE_HISTORY then
      tabtype = Types.DIFFVIEW ---@type eve.builtin.tab.TypeEnum
      break
    end
  end

  tabtype = tabtype or Types.NORMAL ---@type eve.builtin.tab.TypeEnum
  M.set_type(tabnr, tabtype)
  return tabtype
end

---@param tabnr                         integer
---@return boolean
function M.is_valid(tabnr)
  return tabnr > 0 and vim.api.nvim_tabpage_is_valid(tabnr)
end

---@param tabnr                         integer
---@return table<integer, boolean>
function M.list_visible_bufnrs(tabnr)
  local winnrs = vim.api.nvim_tabpage_list_wins(tabnr) ---@type integer[]
  local bufnrs = {} ---@type table<integer, boolean>
  for _, winnr in ipairs(winnrs) do
    local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
    bufnrs[bufnr] = true
  end
  return bufnrs
end

return M
