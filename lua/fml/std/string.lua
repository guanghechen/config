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
---@param width                         integer
---@param pad                           string
---@return string
function M.pad_start(text, width, pad)
  local delta = width - vim.fn.strwidth(text) ---@type integer
  return delta <= 0 and text or (string.rep(pad, delta) .. text)
end

---@param text                          string
---@param width                         integer
---@param pad                           string
---@return string
function M.pad_end(text, width, pad)
  local delta = width - vim.fn.strwidth(text) ---@type integer
  return delta <= 0 and text or (text .. string.rep(pad, delta))
end

---@param text                          string
---@param separator_regex_pattern       string
---@return string[]
function M.split(text, separator_regex_pattern)
  local result = {} ---@type string[]
  local pattern = string.format("([^%s]+)", separator_regex_pattern)
  for match in string.gmatch(text, pattern) do
    table.insert(result, match)
  end
  return result
end

return M
