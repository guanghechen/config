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

return M
