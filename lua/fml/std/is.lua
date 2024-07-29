---@class fml.std.is
local M = {}

---@param value                         any
---@return boolean
function M.array(value)
  if type(value) ~= "table" then
    return false
  end

  if #value > 0 then
    return true
  end

  for key, _ in pairs(table) do
    if type(key) ~= "number" then
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
