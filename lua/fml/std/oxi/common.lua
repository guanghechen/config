local reporter = require("fml.std.reporter")

---@class fml.std.oxi
local M = require("fml.std.oxi.mod")

---@class fml.std.oxi.ICmdResult
---@field public cmd                    string
---@field public error                  ?string
---@field public data                   ?any

---@param text                          string
---@return integer[]
function M.get_line_widths(text)
  local str = M.nvim_tools.get_line_widths(text)
  local raw_result = M.json.parse(str)
  ---@cast raw_result integer[]

  local result = raw_result ---@type integer[]
  return result
end

---@param input string
---@return string
function M.normalize_comma_list(input)
  return M.nvim_tools.normalize_comma_list(input)
end

---@return integer
function M.now()
  return M.nvim_tools.now()
end

---@param text                          string
---@param lwidths                       integer[]
---@return string[]
function M.parse_lines(text, lwidths)
  local offset = 0
  local lines = {} ---@type string[]
  for _, lwidth in ipairs(lwidths) do
    local line = string.sub(text, offset + 1, offset + lwidth)
    table.insert(lines, line)
    offset = offset + lwidth + 1
  end
  return lines
end

---@param from                          string
---@param result_str                    string
---@return boolean
---@return any|nil
function M.resolve_cmd_result(from, result_str)
  local result = M.json.parse(result_str)
  if result == nil or type(result.error) == "string" then
    reporter.error({
      from = from,
      message = "Failed to run command.",
      details = result,
    })
    return false, nil
  end

  ---@cast result fml.std.oxi.ICmdResult
  return true, result.data
end
