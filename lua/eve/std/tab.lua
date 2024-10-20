---@class eve.std.tab
local M = {}

---@param tabnr                         integer|nil
---@return boolean
function M.is_valid(tabnr)
  if tabnr == nil or tabnr == 0 then
    return false
  end

  if not vim.api.nvim_tabpage_is_valid(tabnr) then
    return false
  end
  return true
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
