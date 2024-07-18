---@class fml.std.oxi
local M = require("fml.std.oxi.mod")

---@param pattern                       string
---@param lines                         string[]
---@return fml.types.ui.select.ILineMatch[]
function M.find_match_points(pattern, lines)
  local json_str = M.nvim_tools.find_match_points(pattern, table.concat(lines, "\n")) ---@type string
  local result = M.json.parse(json_str)
  ---@cast result fml.types.ui.select.ILineMatch[]
  return result
end

---@return string
function M.uuid()
  return M.nvim_tools.uuid()
end
