---@class oxi.string.ILineMatch
---@field public lnum                   integer
---@field public score                  integer
---@field public matches                std.t.IMatchPoint[]

---@class oxi.string
local M = {}

---@param text                          string
---@return integer[]
function M.calc_linewidths(text)
  local result = oxi.fn.safe_run("calc_linewidths", text)
  return result or {}
end

---@param text                          string
---@return integer
function M.count_lines(text)
  local result = oxi.fn.safe_run("count_lines", text)
  return result or 0
end

---@param pattern                       string
---@param lines                         string[]
---@param flag_fuzzy                    boolean
---@param flag_regex                    boolean
---@return oxi.string.ILineMatch[]|nil
function M.find_match_points_line_by_line(pattern, lines, flag_fuzzy, flag_regex)
  local text = table.concat(lines, "\n") ---@type string
  local result = oxi.fn.safe_run("find_match_points_line_by_line", pattern, text, flag_fuzzy, flag_regex)
  return result
end

---@param text                          string
---@param lwidths                       ?integer[]
---@return string[]
function M.parse_lines(text, lwidths)
  lwidths = lwidths or M.calc_linewidths(text) ---@type integer[]
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
