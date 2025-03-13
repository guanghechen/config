---@class eve.collection.ISubscriber : eve.collection.IDisposable
---@field public next                   fun(self: eve.collection.ISubscriber, value: eve.t.T, value_prev: eve.t.T| nil): nil

---@class eve.collection.subscriber.IProps
---@field on_next                       fun(value: any, value_prev: any|nil):nil
---@field on_dispose                    ?fun():nil

---@class eve.collection.Subscriber : eve.collection.ISubscriber
---@field private _on_next              fun(value: any, value_prev: any|nil):nil
---@field private _on_dispose           fun():nil
local M = {}
M.__index = M

---@param props eve.collection.subscriber.IProps
---@return eve.collection.Subscriber
function M.new(props)
  local self = setmetatable({}, M)

  self._disposed = false ---@type boolean
  self._on_dispose = props.on_dispose or eve.std.fn.noop ---@type fun(): nil
  self._on_next = props.on_next ---@type fun(value: any, value_prev: any|nil): nil

  return self
end

---@return boolean
function M:is_disposed()
  return self._disposed
end

---@return nil
function M:dispose()
  if not self._disposed then
    self._disposed = true
    self._on_dispose()
  end
end

---@param value any
---@param value_prev any
---@return nil
function M:next(value, value_prev)
  if not self._disposed then
    self._on_next(value, value_prev)
  end
end

return M
