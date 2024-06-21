---@class guanghechen.util.string
local M = {}

-- capitalization util, only capitalizes the first character of the whole word
---@param str string
function M.capitalize(str)
  local capitalized = str:gsub("(%a)(%a+)", function(a, b)
    return string.upper(a) .. string.lower(b)
  end)
  return capitalized:gsub("_", "")
end

---@param text string
---@param separator_regex_pattern string
---@return string[]
function M.split(text, separator_regex_pattern)
  local result = {}
  local pattern = string.format("([^%s]+)", separator_regex_pattern)

  for match in string.gmatch(text, pattern) do
    table.insert(result, match)
  end

  return result
end

---@param text string
---@param length number
---@param pad string
function M.padStart(text, length, pad)
  local delta = length - #text
  if delta <= 0 then
    return text
  end
  return string.rep(pad, delta) .. text
end

---@param text      string
---@param start_pos integer
---@param end_pos   integer
function M.count_newlines(text, start_pos, end_pos)
  local count = 0 ---@type integer
  for i = start_pos, end_pos do
    if text:sub(i, i) == "\n" then
      count = count + 1
    end
  end
  return count
end

return M
