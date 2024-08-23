---@class fml.std.oxi
local M = require("fml.std.oxi.mod")

---@class fml.std.oxi.string.ILineMatch
---@field public idx                    integer
---@field public score                  integer
---@field public matches                fml.std.oxi.search.IMatchPoint[]

---@param text                          string
---@return integer
function M.count_lines(text)
  return M.nvim_tools.count_lines(text)
end

---@param pattern                       string
---@param lines                         string[]
---@param flag_fuzzy                    boolean
---@return fml.std.oxi.string.ILineMatch[]
function M.find_match_points(pattern, lines, flag_fuzzy)
  local json_str = M.nvim_tools.find_match_points(pattern, table.concat(lines, "\n"), flag_fuzzy) ---@type string
  local matches = M.json.parse(json_str)
  ---@cast matches fml.std.oxi.string.ILineMatch[]
  return matches
end

---@param text                          string
---@return integer[]
function M.get_line_widths(text)
  local str = M.nvim_tools.get_line_widths(text)
  local raw_result = M.json.parse(str)
  ---@cast raw_result integer[]

  local result = raw_result ---@type integer[]
  return result
end

---@param text                          string
---@param lwidths                       ?integer[]
---@return string[]
function M.parse_lines(text, lwidths)
  lwidths = lwidths or M.get_line_widths(text) ---@type integer[]
  local offset = 0
  local lines = {} ---@type string[]
  for _, lwidth in ipairs(lwidths) do
    local line = string.sub(text, offset + 1, offset + lwidth)
    table.insert(lines, line)
    offset = offset + lwidth + 1
  end
  return lines
end

---@return string
function M.uuid()
  return M.nvim_tools.uuid()
end
