---@class std.collection.IUnsubscribable
---@field public unsubscribe            fun(self: std.collection.IUnsubscribable):nil

---@class std.collection.IDisposable
---@field public isdisposed            fun(self: std.collection.IDisposable): boolean Check if the disposable disposed.
---@field public dispose                fun(self: std.collection.IDisposable): boolean Dispose the disposable.

---@class std.collection.disposable.IProps
---@field public on_dispose             fun():nil

---@class std.collection.Disposable : std.collection.IDisposable
---@field private _on_dispose           fun():nil
local M = {}
M.__index = M

---@param props std.collection.disposable.IProps
---@return std.collection.Disposable
function M.new(props)
  local self = setmetatable({}, M)

  ---@type function
  self._on_dispose = props.on_dispose

  ---@type boolean
  self._disposed = false
  return self
end

---@param unsubscribable                std.collection.IUnsubscribable
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
