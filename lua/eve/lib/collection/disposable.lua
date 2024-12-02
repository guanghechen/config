---@class eve.lib.collection.IDisposable
---@field public is_disposed            fun(self: eve.lib.collection.IDisposable): boolean Check if the disposable disposed.
---@field public dispose                fun(self: eve.lib.collection.IDisposable): boolean Dispose the disposable.

---@class eve.lib.collection.disposable.IProps
---@field public on_dispose             fun():nil

---@class eve.lib.collection.Disposable : eve.lib.collection.IDisposable
---@field private _on_dispose           fun():nil
local M = {}
M.__index = M

---@param props eve.lib.collection.disposable.IProps
---@return eve.lib.collection.Disposable
function M.new(props)
  local self = setmetatable({}, M)

  ---@type function
  self._on_dispose = props.on_dispose

  ---@type boolean
  self._disposed = false
  return self
end

---@param unsubscribable                eve.lib.collection.IUnsubscribable
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
