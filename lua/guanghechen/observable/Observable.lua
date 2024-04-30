local BatchDisposable = require("guanghechen.disposable.BatchDisposable")
local Subscribers = require("guanghechen.subscriber.Subscribers")

---@class guanghechen.observable.Observable.util
local util = {
  comparator = require("guanghechen.util.comparator"),
  debug = require("guanghechen.util.debug"),
  misc = require("guanghechen.util.misc"),
}

---@class guanghechen.observable.Observable : guanghechen.types.IObservable
local Observable = setmetatable({}, BatchDisposable)

---@class guanghechen.observable.Observable.IOptions
---@field public equals? guanghechen.types.IEquals  Determine whether the two values are equal.

---@param o guanghechen.types.IBatchDisposable
---@param default_value guanghechen.types.T
---@param options? guanghechen.observable.Observable.IOptions
---@return guanghechen.observable.Observable
function Observable:new(o, default_value, options)
  o = o or BatchDisposable:new()

  options = options or options
  ---@cast options guanghechen.observable.Observable.IOptions

  setmetatable(o, self)

  ---@type guanghechen.types.IEquals
  local equals = options.equals and options.equals or util.comparator.shallow_equals

  ---@type guanghechen.types.ISubscribers
  self._subscribers = Subscribers:new()

  ---@type guanghechen.types.T
  self._value = default_value

  ---@type guanghechen.types.T | nil
  self._value_last_notified = nil

  ---@type guanghechen.types.IEquals
  self.equals = equals

  ---@type guanghechen.types.IBatchDisposable
  self._super = o

  ---@cast o guanghechen.observable.Observable
  return o
end

---@return nil
function Observable:dispose()
  if self:isDisposed() then
    return
  end

  self._super:dispose()

  -- Dispose subscribers
  self._subscribers:dispose()
end

---@param value guanghechen.types.T
---@param options? guanghechen.types.IObservableNextOptions
---@return nil
function Observable:next(value, options)
  options = options or {}
  ---@cast options guanghechen.types.IObservableNextOptions

  if self:isDisposed() then
    ---@type boolean
    local strict = options.strict ~= nil and options.strict or true
    if strict then
      error("Don't update a disposed observable. value: " .. util.debug.inspect(value))
    end
    return
  end

  ---@type boolean
  local force = options.force ~= nil and options.force or false
  if force or not self.equals(value, self._value) then
    self._value = value
    self:_notify()
  end
end

---@param subscriber guanghechen.types.ISubscriber
---@return nil
function Observable:subscirbe(subscriber)
  if subscriber:isDisposed() then
    return util.misc.noop_unsubscribable
  end

  ---@type guanghechen.types.T | nil
  local value_prev = self._value_last_notified

  ---@type guanghechen.types.T
  local value = self._value

  if self:isDisposed() then
    subscriber:next(value, value_prev)
    subscriber:dispose()
    return util.misc.noop_unsubscribable
  end

  subscriber:next(value, value_prev)
  return self._subscribers:subscirbe(subscriber)
end

---@return nil
function Observable:_notify()
  ---@type guanghechen.types.T | nil
  local value_prev = self._value_last_notified

  ---@type guanghechen.types.T
  local value = self._value

  self._value_last_notified = value
  self._subscribers:notify(value, value_prev)
end

return Observable
