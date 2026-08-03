---@class conf.osx
local M = {}

---@param config table
function M.setup(config)
  require("conf.osx.font-maple").setup(config)
  require("conf.osx.keymap").setup(config)
end

return M
