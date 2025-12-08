---@class conf.wsl
local M = {}

---@param config table
function M.setup(config)
  require("conf.wsl.font-maple").setup(config)
  require("conf.wsl.keymap").setup(config)
end

return M
