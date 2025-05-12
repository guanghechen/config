local __module_name__ = "eve.std.collection.subscriber" ---@type string

---@alias eve.std.collection.subscriber.IOnDispose
---| fun(): nil

---@alias eve.std.collection.subscriber.IOnNext
---| fun(value: any, value_prev: any|nil):nil

---@class eve.std.collection.ISubscriber : eve.std.collection.IDisposable
---@field public next                   fun(self: eve.std.collection.ISubscriber, value: eve.t.T, value_prev: eve.t.T| nil): nil

---@class eve.std.collection.subscriber.IProps
---@field on_dispose                    ?eve.std.collection.subscriber.IOnDispose
---@field on_next                       eve.std.collection.subscriber.IOnNext

---@class eve.std.collection.Subscriber : eve.std.collection.ISubscriber
---@field private _on_dispose           eve.std.collection.subscriber.IOnDispose
---@field private _on_next              eve.std.collection.subscriber.IOnNext
local M = {}
M.__index = M

---@param props eve.std.collection.subscriber.IProps
---@return eve.std.collection.Subscriber
function M.new(props)
  local on_dispose = props.on_dispose or eve.std.fn.noop ---@type eve.std.collection.subscriber.IOnDispose
  local on_next = props.on_next ---@type eve.std.collection.subscriber.IOnNext

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

  local on_dispose = self._on_dispose ---@type eve.std.collection.subscriber.IOnDispose

  self._disposed = true
  self._on_next = nil
  self._on_dispose = nil

  on_dispose()
end

---@param value                         eve.t.T
---@param value_prev                    eve.t.T|nil
---@return nil
function M:next(value, value_prev)
  self:__health__()
  self._on_next(value, value_prev)
end

---@protected
---@return nil
function M:__health__()
  if self._disposed then
    local message = string.format("[%s] already been disposed.", __module_name__) ---@type string
    error(message)
  end
end

return M
