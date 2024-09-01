---@class fc.std.oxi
local M = require("fc.std.oxi.mod")

---@class fc.std.oxi.string.ILineMatch
---@field public lnum                   integer
---@field public score                  integer
---@field public matches                fml.types.IMatchPoint[]

---@param text                          string
---@return integer
function M.count_lines(text)
  return M.nvim_tools.count_lines(text)
end

---@param pattern                       string
---@param lines                         string[]
---@param flag_fuzzy                    boolean
---@param flag_regex                    boolean
---@return fc.std.oxi.string.ILineMatch[]|nil
function M.find_match_points_line_by_line(pattern, lines, flag_fuzzy, flag_regex)
  local text = table.concat(lines, "\n") ---@type string

  local ok, data = M.resolve_fun_result(
    "fc.std.oxi.find_match_points_line_by_line",
    M.nvim_tools.find_match_points_line_by_line(pattern, text, flag_fuzzy, flag_regex)
  )

  if ok then
    ---@cast data fc.std.oxi.string.ILineMatch[]
    return data
  end
  return nil
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
---@param offsets                       integer[]
---@return fml.types.IMatchLocation[]
function M.get_locations(text, offsets)
  local ok, data =
    M.resolve_fun_result("fc.std.oxi.get_locations", M.nvim_tools.get_locations(text, table.concat(offsets, ",")))
  return ok and data or {}
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
