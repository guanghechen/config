---@class conf.nix
local M = {}

---@param config table
function M.setup(config)
  require("conf.nix.font-maple").setup(config)
  require("conf.nix.keymap").setup(config)
end

return M
