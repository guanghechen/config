---@class conf.win
local M = {}

---@param config table
function M.setup(config)
  require("conf.win.font-maple").setup(config)
  require("conf.win.keymap").setup(config)
  require("conf.win.profile").setup(config)
end

return M
