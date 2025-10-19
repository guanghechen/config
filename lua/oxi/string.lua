---@class oxi.string.ILineMatch
---@field public lnum                   integer
---@field public score                  integer
---@field public matches                std.t.IMatchPoint[]

---@class oxi.string
local M = {}

---@param text                          string
---@param lwidths                       ?integer[]
---@return string[]
function M.parse_lines(text, lwidths)
  lwidths = lwidths or rstd.string.calc_linewidths(text) ---@type integer[]
  local offset = 0 ---@type integer
  local lines = {} ---@type string[]
  for _, lwidth in ipairs(lwidths) do
    local line = string.sub(text, offset + 1, offset + lwidth)
    table.insert(lines, line)
    offset = offset + lwidth + 1
  end
  return lines
end

return M
