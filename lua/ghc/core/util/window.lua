---@class ghc.core.util.window
local M = {}

---@param winnr number
---@return boolean
function M.is_floating(winnr)
  local config = vim.api.nvim_win_get_config(winnr)
  return config.relative ~= nil and config.relative ~= ""
end

return M
