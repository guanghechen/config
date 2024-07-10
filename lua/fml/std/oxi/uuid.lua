---@class fml.std.oxi
local M = require("fml.std.oxi.mod")

---@return string
function M.uuid()
  return M.nvim_tools.uuid()
end
