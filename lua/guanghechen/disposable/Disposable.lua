---@class guanghechen.disposable.Disposable : IDisposable
local Disposable = {}

---@param o table|nil
---@param onDispose fun():nil
---@return guanghechen.disposable.Disposable
function Disposable:new(o, onDispose)
  o = o or {}
  setmetatable(o, self)

  ---@type function
  self._onDisponse = onDispose

  ---@type boolean
  self._disposed = false
  return o
end

---@return boolean
function Disposable:isDisposed()
  return self._disposed
end

---@return nil
function Disposable:dispose()
  if self._disposed then
    return
  end

  self._disposed = true
  self._onDisponse()
end

return Disposable
