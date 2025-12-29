local __module_name__ = "stl.c.subscriber" ---@type string

---@alias stl.c.subscriber.IOnDispose
---| fun(): nil

---@alias stl.c.subscriber.IOnNext
---| fun(value: any, value_prev: any|nil):nil

---@class stl.c.ISubscriber : stl.c.IDisposable
---@field public next                   fun(self: stl.c.ISubscriber, value: stl.t.T, value_prev: stl.t.T| nil): nil

---@class stl.c.subscriber.IProps
---@field public on_dispose             stl.c.subscriber.IOnDispose|nil
---@field public on_next                stl.c.subscriber.IOnNext

---@class stl.c.Subscriber : stl.c.ISubscriber
---@field protected _on_dispose         stl.c.subscriber.IOnDispose
---@field protected _on_next            stl.c.subscriber.IOnNext
local M = {}
M.__index = M

---@param props                         stl.c.subscriber.IProps
---@return stl.c.Subscriber
function M.new(props)
  local on_dispose = props.on_dispose or stl.fn.noop ---@type stl.c.subscriber.IOnDispose
  local on_next = props.on_next ---@type stl.c.subscriber.IOnNext

  local self = setmetatable({}, M)
  self._disposed = false
  self._on_dispose = on_dispose
  self._on_next = on_next
  return self
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

  local on_dispose = self._on_dispose ---@type stl.c.subscriber.IOnDispose

  self._disposed = true
  self._on_next = nil
  self._on_dispose = nil

  on_dispose()
end

---@param value                         stl.t.T
---@param value_prev                    stl.t.T|nil
---@return nil
function M:next(value, value_prev)
  self:__health__()
  self._on_next(value, value_prev)
end

----------------------------------------------------------------------------------------------------

---@protected
---@return nil
function M:__health__()
  if self._disposed then
    local message = string.format("[%s] already been disposed.", __module_name__) ---@type string
    error(message)
  end
end

return M
