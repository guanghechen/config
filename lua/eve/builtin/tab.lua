---@class eve.builtin.tab
local M = {}

---@param tabnr                         integer
---@return boolean
function M.is_valid(tabnr)
  return tabnr > 0 and vim.api.nvim_tabpage_is_valid(tabnr)
end

return M
