---@class fml.std.string
local M = {}

---@param text                          string
function M.capitalize(text)
  local capitalized = text:gsub("(%a)(%a+)", function(a, b)
    return string.upper(a) .. string.lower(b)
  end)
  return capitalized:gsub("_", "")
end

---@param text                          string
---@return boolean
function M.is_blank_string(text)
  return type(text) == "string" and #text == 0
end

---@param text                          string
---@return boolean
function M.is_non_blank_string(text)
  return type(text) == "string" and #text > 0
end

---@param text                          string
---@param length                        number
---@param pad string
function M.pad_start(text, length, pad)
  local delta = length - #text
  if delta <= 0 then
    return text
  end
  return string.rep(pad, delta) .. text
end

---@param text                          string
---@param separator_regex_pattern       string
---@return string[]
function M.split(text, separator_regex_pattern)
  local result = {}
  local pattern = string.format("([^%s]+)", separator_regex_pattern)

  for match in string.gmatch(text, pattern) do
    table.insert(result, match)
  end

  return result
end

return M

