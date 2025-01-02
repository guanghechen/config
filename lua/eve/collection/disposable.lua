---@class eve.collection.IDisposable
---@field public is_disposed            fun(self: eve.collection.IDisposable): boolean Check if the disposable disposed.
---@field public dispose                fun(self: eve.collection.IDisposable): boolean Dispose the disposable.

---@class eve.collection.disposable.IProps
---@field public on_dispose             fun():nil

---@class eve.collection.Disposable : eve.collection.IDisposable
---@field private _on_dispose           fun():nil
local M = {}
M.__index = M

---@param props eve.collection.disposable.IProps
---@return eve.collection.Disposable
function M.new(props)
  local self = setmetatable({}, M)

  ---@type function
  self._on_dispose = props.on_dispose

  ---@type boolean
  self._disposed = false
  return self
end

---@param unsubscribable                eve.collection.IUnsubscribable
function M.from_unsubscribable(unsubscribable)
  return M.new({
    on_dispose = function()
      unsubscribable:unsubscribe()
    end,
  })
end

---@return boolean
function M:is_disposed()
  return self._disposed
end

---@return nil
function M:dispose()
  if self._disposed then
    return
  end

  self._disposed = true
  self._on_dispose()
end

return M
