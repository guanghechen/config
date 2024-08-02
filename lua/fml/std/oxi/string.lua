---@class fml.std.oxi
local M = require("fml.std.oxi.mod")

---@class fml.std.oxi.string.ILineMatchPiece
---@field public l                      integer
---@field public r                      integer

---@class fml.std.oxi.string.ILineMatch
---@field public idx                    integer
---@field public score                  integer
---@field public pieces                 fml.std.oxi.string.ILineMatchPiece[]

---@param pattern                       string
---@param lines                         string[]
---@return fml.std.oxi.string.ILineMatch[]
function M.find_match_points(pattern, lines)
  local json_str = M.nvim_tools.find_match_points(pattern, table.concat(lines, "\n")) ---@type string
  local matches = M.json.parse(json_str)
  ---@cast matches fml.std.oxi.string.ILineMatch[]
  return matches
end

---@return string
function M.uuid()
  return M.nvim_tools.uuid()
end
