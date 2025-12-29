---@class stl.c.IUnsubscribable
---@field public unsubscribe            fun(self: stl.c.IUnsubscribable): nil

---@class stl.c.IDisposable
---@field public isdisposed             fun(self: stl.c.IDisposable): boolean Check if the disposable disposed.
---@field public dispose                fun(self: stl.c.IDisposable): boolean Dispose the disposable.

---@class stl.c.disposable.IProps
---@field public on_dispose             fun():nil

---@class stl.c.Disposable : stl.c.IDisposable
---@field protected _on_dispose         fun():nil
local M = {}
M.__index = M

---@param props                         stl.c.disposable.IProps
---@return stl.c.Disposable
function M.new(props)
  local self = setmetatable({}, M)

  ---@type function
  self._on_dispose = props.on_dispose

  ---@type boolean
  self._disposed = false
  return self
end

---@param unsubscribable                stl.c.IUnsubscribable
function M.from_unsubscribable(unsubscribable)
  return M.new({
    on_dispose = function()
      unsubscribable:unsubscribe()
    end,
  })
end

---@return boolean
function M:isdisposed()
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
