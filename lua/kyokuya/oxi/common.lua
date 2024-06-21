local nvim_tools = require("nvim_tools")

---@class kyokuya.oxi
local M = require("kyokuya.oxi.mod")

---@param input string
---@return string
function M.normalize_comma_list(input)
  return nvim_tools.normalize_comma_list(input)
end
