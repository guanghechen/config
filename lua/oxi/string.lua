---@class oxi.string.ILineMatch
---@field public lnum                   integer
---@field public score                  integer
---@field public matches                std.t.IMatchPoint[]

---@class oxi.string
local M = {}

---@param text                          string
---@return integer
function M.count_lines(text)
  local nvim_tools = require("nvim_tools")
  return nvim_tools.count_lines(text)
end

---@param pattern                       string
---@param lines                         string[]
---@param flag_fuzzy                    boolean
---@param flag_regex                    boolean
---@return oxi.string.ILineMatch[]|nil
function M.find_match_points_line_by_line(pattern, lines, flag_fuzzy, flag_regex)
  local text = table.concat(lines, "\n") ---@type string

  local nvim_tools = require("nvim_tools")
  local ok, data = oxi.fn.resolve_fun_result(
    "find_match_points_line_by_line",
    nvim_tools.find_match_points_line_by_line(pattern, text, flag_fuzzy, flag_regex)
  )

  if ok then
    ---@cast data                       oxi.string.ILineMatch[]
    return data
  end
  return nil
end

---@param text                          string
---@return integer[]
function M.get_line_widths(text)
  local nvim_tools = require("nvim_tools")
  local str = nvim_tools.get_line_widths(text)
  local raw_result = std.json.parse(str)
  ---@cast raw_result                   integer[]

  local result = raw_result ---@type integer[]
  return result
end

---@param text                          string
---@param lwidths                       ?integer[]
---@return string[]
function M.parse_lines(text, lwidths)
  lwidths = lwidths or M.get_line_widths(text) ---@type integer[]
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
