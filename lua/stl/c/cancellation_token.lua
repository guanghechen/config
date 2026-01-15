---@diagnostic disable-next-line: unused-local
local __module_name__ = "stl.c.cancellation_token" ---@type string

local noop = function() end

---@class stl.c.cancellation_token.IProps
---@field public on_cancel              ?fun(): nil

---@class stl.c.CancellationToken : stl.c.IDisposable
---@field protected _cancelled          boolean
---@field protected _callbacks          fun()[]
local M = {}
M.__index = M

---Create a new CancellationToken.
---@param props                         ?stl.c.cancellation_token.IProps
---@return stl.c.CancellationToken
function M.new(props)
  local self = setmetatable({}, M)
  self._cancelled = false
  self._callbacks = {}
  if props and props.on_cancel then
    self._callbacks[1] = props.on_cancel
  end
  return self
end

---Check if the token is cancelled.
---@return boolean
function M:is_cancelled()
  return self._cancelled
end

---Cancel the token and trigger all callbacks.
---@return nil
function M:cancel()
  if self._cancelled then
    return
  end
  self._cancelled = true
  for _, cb in ipairs(self._callbacks) do
    pcall(cb)
  end
  self._callbacks = {}
end

---Register a callback to be called when the token is cancelled.
---If already cancelled, the callback is invoked immediately.
---@param callback                      fun(): nil
---@return stl.c.IUnsubscribable
function M:on_cancel(callback)
  if self._cancelled then
    pcall(callback)
    return { unsubscribe = noop }
  end
  self._callbacks[#self._callbacks + 1] = callback
  local unsubscribed = false
  return {
    unsubscribe = function()
      if unsubscribed then
        return
      end
      unsubscribed = true
      for i, cb in ipairs(self._callbacks) do
        if cb == callback then
          table.remove(self._callbacks, i)
          break
        end
      end
    end,
  }
end

---Throw an error if the token is cancelled. Use in async functions.
---@async
function M:throw_if_cancelled()
  if self._cancelled then
    error("Operation cancelled", 2)
  end
end

---IDisposable implementation: check if disposed.
---@return boolean
function M:isdisposed()
  return self._cancelled
end

---IDisposable implementation: dispose by cancelling.
---@return boolean
function M:dispose()
  local was_cancelled = self._cancelled
  self:cancel()
  return not was_cancelled
end

return M
