local __module_name__ = "ark.c.subscriber" ---@type string

---@alias ark.c.subscriber.IOnDispose
---| fun(): nil

---@alias ark.c.subscriber.IOnNext
---| fun(value: any, value_prev: any|nil):nil

---@class ark.c.ISubscriber : ark.c.IDisposable
---@field public next                   fun(self: ark.c.ISubscriber, value: ark.t.T, value_prev: ark.t.T| nil): nil

---@class ark.c.subscriber.IProps
---@field public on_dispose             ark.c.subscriber.IOnDispose|nil
---@field public on_next                ark.c.subscriber.IOnNext

---@class ark.c.Subscriber : ark.c.ISubscriber
---@field protected _on_dispose         ark.c.subscriber.IOnDispose
---@field protected _on_next            ark.c.subscriber.IOnNext
local M = {}
M.__index = M

---@param props                         ark.c.subscriber.IProps
---@return ark.c.Subscriber
function M.new(props)
  local on_dispose = props.on_dispose or stl.fn.noop ---@type ark.c.subscriber.IOnDispose
  local on_next = props.on_next ---@type ark.c.subscriber.IOnNext

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

  local on_dispose = self._on_dispose ---@type ark.c.subscriber.IOnDispose

  self._disposed = true
  self._on_next = nil
  self._on_dispose = nil

  on_dispose()
end

---@param value                         ark.t.T
---@param value_prev                    ark.t.T|nil
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
