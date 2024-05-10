---@class guanghechen.disposable.Disposable : guanghechen.types.IDisposable
---@field private _onDispose fun():nil
local Disposable = {}
Disposable.__index = Disposable

---@param onDispose fun():nil
---@return guanghechen.disposable.Disposable
function Disposable.new(onDispose)
  local self = setmetatable({}, Disposable)

  ---@type function
  self._onDispose = onDispose

  ---@type boolean
  self._disposed = false
  return self
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
  self._onDispose()
end

return Disposable
