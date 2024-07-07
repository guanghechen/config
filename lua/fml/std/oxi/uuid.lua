---@class fml.std.oxi
local M = require("fml.std.oxi.mod")

function M.uuid()
  return M.nvim_tools.uuid("")
end
