local __module_name__ = "std.collection.subscriber" ---@type string

---@alias std.collection.subscriber.IOnDispose
---| fun(): nil

---@alias std.collection.subscriber.IOnNext
---| fun(value: any, value_prev: any|nil):nil

---@class std.collection.ISubscriber : std.collection.IDisposable
---@field public next                   fun(self: std.collection.ISubscriber, value: std.t.T, value_prev: std.t.T| nil): nil

---@class std.collection.subscriber.IProps
---@field on_dispose                    ?std.collection.subscriber.IOnDispose
---@field on_next                       std.collection.subscriber.IOnNext

---@class std.collection.Subscriber : std.collection.ISubscriber
---@field private _on_dispose           std.collection.subscriber.IOnDispose
---@field private _on_next              std.collection.subscriber.IOnNext
local M = {}
M.__index = M

---@param props std.collection.subscriber.IProps
---@return std.collection.Subscriber
function M.new(props)
  local on_dispose = props.on_dispose or std.fn.noop ---@type std.collection.subscriber.IOnDispose
  local on_next = props.on_next ---@type std.collection.subscriber.IOnNext

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

  local on_dispose = self._on_dispose ---@type std.collection.subscriber.IOnDispose

  self._disposed = true
  self._on_next = nil
  self._on_dispose = nil

  on_dispose()
end

---@param value                         std.t.T
---@param value_prev                    std.t.T|nil
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
