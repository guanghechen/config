---@class conf.mac
local M = {}

---@param config table
function M.setup(config)
  require("conf.mac.keymap").setup(config)
end

return M
