---@class fml.core.oxi
local M = require("fml.core.oxi.mod")

---@param input string
---@return string
function M.normalize_comma_list(input)
  return M.nvim_tools.normalize_comma_list(input)
end
