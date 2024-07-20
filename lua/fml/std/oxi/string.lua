---@class fml.std.oxi
local M = require("fml.std.oxi.mod")

---@param pattern                       string
---@param lines                         string[]
---@return fml.types.ui.select.ILineMatch[]
function M.find_match_points(pattern, lines)
  local json_str = M.nvim_tools.find_match_points(pattern, table.concat(lines, "\n")) ---@type string
  local matches = M.json.parse(json_str)
  ---@cast matches fml.types.ui.select.ILineMatch[]
  return matches
end

---@return string
function M.uuid()
  return M.nvim_tools.uuid()
end
