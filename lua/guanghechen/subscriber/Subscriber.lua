---@class guanghechen.subscriber.Subscriber.util
local util = {
  misc = require("guanghechen.util.misc"),
}

---@class guanghechen.subscriber.Subscriber : guanghechen.types.ISubscriber
local Subscriber = {}

---@class guanghechen.subscriber.Subscriber.IOptions
---@field onNext fun(value: any, prev_value: any|nil):nil
---@field onDispose? fun():nil

---@param o table|nil
---@param options guanghechen.subscriber.Subscriber.IOptions
---@return guanghechen.subscriber.Subscriber
function Subscriber:new(o, options)
  o = o or {}
  setmetatable(o, self)

  ---@type fun(value: any, prev_value: any|nil):nil
  self._onNext = options.onNext

  ---@type fun():nil
  self._onDisponse = options.onDispose or util.misc.noop

  ---@type boolean
  self._disposed = false

  return o
end

---@return boolean
function Subscriber:isDisposed()
  return self._disposed
end

---@return nil
function Subscriber:dispose()
  if not self._disposed then
    self._disposed = true
    self._onDisponse()
  end
end

---@param value any
---@param prev_value any
---@return nil
function Subscriber:next(value, prev_value)
  if not self._disposed then
    self._onNext(value, prev_value)
  end
end

return Subscriber
