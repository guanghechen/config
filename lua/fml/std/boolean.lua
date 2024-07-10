---@class ghc.std.boolean
local M = {}

---@param value                         boolean|nil
---@param default_value                 boolean
---@return boolean
function M.cover(value, default_value)
  if type(value) ~= "boolean" then
    return default_value
  end
  return value
end

return M
