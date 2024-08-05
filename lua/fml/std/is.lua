local typs = require("fml.std.typ")

---@class fml.std.is
local M = {}

---@param value                         any
---@return boolean
function M.array(value)
  if type(value) ~= "table" then
    return false
  end

  local metatable = getmetatable(value)
  if metatable ~= nil and metatable.json_type ~= "null" then
    return metatable.json_type == typs.array.json_type
  end

  if #value > 0 then
    return true
  end

  for key, val in pairs(table) do
    if type(key) ~= "number" and type(val) ~= "function" then
      return false
    end
  end

  return true
end

---@param value                         any
---@return boolean
function M.disposable(value)
  return type(value) == "table" and type(value.isDisposable) == "function" and type(value.dispose) == "function"
end

---@param value                         any
---@return boolean
function M.observable(value)
  return type(value) == "table"
    and type(value.snapshot) == "function"
    and type(value.next) == "function"
    and type(value.subscribe) == "function"
end

return M
