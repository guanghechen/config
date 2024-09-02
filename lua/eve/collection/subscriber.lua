local util = require("eve.std.util")

---@class eve.collection.Subscriber : eve.types.collection.ISubscriber
---@field private _on_next              fun(value: any, value_prev: any|nil):nil
---@field private _on_dispose           fun():nil
local M = {}
M.__index = M

---@class eve.collection.Subscriber.IProps
---@field on_next                       fun(value: any, value_prev: any|nil):nil
---@field on_dispose                    ?fun():nil

---@param props eve.collection.Subscriber.IProps
---@return eve.collection.Subscriber
function M.new(props)
  local self = setmetatable({}, M)

  self._disposed = false ---@type boolean
  self._on_dispose = props.on_dispose or util.noop ---@type fun(): nil
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
