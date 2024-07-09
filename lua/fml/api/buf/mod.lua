local std_array = require("fml.std.array")

---@class fml.api.buf
local M = {}

---@param bufnr                         integer
---@return boolean
function M.is_visible(bufnr)
  local winnrs = vim.api.nvim_tabpage_list_wins(0) ---@type integer[]
  return std_array.some(winnrs, function(winnr)
    local win_bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
    return win_bufnr == bufnr
  end)
end

return M
