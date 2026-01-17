---@alias stl.nvim.tab.TypeEnum
---| "diffview"
---| "normal"

---@class stl.nvim.tab.TypeEnumClass
local TypeEnum = {
  DIFFVIEW = "diffview",
  NORMAL = "normal",
}

---@class stl.nvim.tab.TypeSetClass
local TypeSet = {
  ALL = { TypeEnum.NORMAL, TypeEnum.DIFFVIEW },
  DIFFVIEW = { TypeEnum.DIFFVIEW },
  NORMAL = { TypeEnum.NORMAL },
}

---@class stl.nvim.tab
local M = {}

M.TypeEnum = vim.deepcopy(TypeEnum)
M.TypeSet = vim.deepcopy(TypeSet)

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
