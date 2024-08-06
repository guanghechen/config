---@class fml.std.oxi
local M = require("fml.std.oxi.mod")

---@return integer
function M.now()
  return M.nvim_tools.now()
end

---@param input string
---@return string
function M.normalize_comma_list(input)
  return M.nvim_tools.normalize_comma_list(input)
end
