---@class ark.t.IUnsubscribable
---@field public unsubscribe            fun(self: ark.t.IUnsubscribable): nil

---@class ark.t.IDisposable
---@field public isdisposed             fun(self: ark.t.IDisposable): boolean Check if the disposable disposed.
---@field public dispose                fun(self: ark.t.IDisposable): boolean Dispose the disposable.

---@class ark.c.disposable.IProps
---@field public on_dispose             fun():nil

---@class ark.c.Disposable : ark.t.IDisposable
---@field protected _on_dispose         fun():nil
local M = {}
M.__index = M

---@param props                         ark.c.disposable.IProps
---@return ark.c.Disposable
function M.new(props)
  local self = setmetatable({}, M)

  ---@type function
  self._on_dispose = props.on_dispose

  ---@type boolean
  self._disposed = false
  return self
end

---@param unsubscribable                ark.t.IUnsubscribable
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
