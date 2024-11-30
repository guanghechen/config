local functional = require("eve.lib.functional")

---@class eve.lib.collection.ISubscriber : eve.lib.collection.IDisposable
---@field public next                   fun(self: eve.lib.collection.ISubscriber, value: eve.t.T, value_prev: eve.t.T| nil): nil

---@class eve.lib.collection.subscriber.IProps
---@field on_next                       fun(value: any, value_prev: any|nil):nil
---@field on_dispose                    ?fun():nil

---@class eve.lib.collection.Subscriber : eve.lib.collection.ISubscriber
---@field private _on_next              fun(value: any, value_prev: any|nil):nil
---@field private _on_dispose           fun():nil
local M = {}

---@param props eve.lib.collection.subscriber.IProps
---@return eve.lib.collection.Subscriber
function M.new(props)
  local self = setmetatable({}, { __index = M })

  self._disposed = false ---@type boolean
  self._on_dispose = props.on_dispose or functional.noop ---@type fun(): nil
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
