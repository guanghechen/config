local util_misc = require("guanghechen.util.misc")

---@class guanghechen.subscriber.Subscriber : guanghechen.types.ISubscriber
---@field private _onNext fun(value: any, value_prev: any|nil):nil
---@field private _onDispose fun():nil
local Subscriber = {}
Subscriber.__index = Subscriber

---@class guanghechen.subscriber.Subscriber.IOptions
---@field onNext fun(value: any, value_prev: any|nil):nil
---@field onDispose? fun():nil

---@param options guanghechen.subscriber.Subscriber.IOptions
---@return guanghechen.subscriber.Subscriber
function Subscriber.new(options)
  local self = setmetatable({}, Subscriber)

  ---@type fun(value: any, value_prev: any|nil):nil
  self._onNext = options.onNext

  ---@type fun():nil
  self._onDispose = options.onDispose or util_misc.noop

  ---@type boolean
  self._disposed = false

  return self
end

---@return boolean
function Subscriber:is_disposed()
  return self._disposed
end

---@return nil
function Subscriber:dispose()
  if not self._disposed then
    self._disposed = true
    self._onDispose()
  end
end

---@param value any
---@param value_prev any
---@return nil
function Subscriber:next(value, value_prev)
  if not self._disposed then
    self._onNext(value, value_prev)
  end
end

return Subscriber
