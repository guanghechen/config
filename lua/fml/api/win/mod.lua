---@class fml.api.win.IHistoryItem
---@field public bufnr number
---@field public filepath string

---@class fml.api.win.IHistoryItemEntry
---@field public display string
---@field public ordinal string
---@field public item fml.api.win.IHistoryItem
---@field public item_index number

---@class fml.api.win
local M = {}

---@param winnr number
---@return boolean
function M.is_floating(winnr)
  local config = vim.api.nvim_win_get_config(winnr)
  return config.relative ~= nil and config.relative ~= ""
end

return M
