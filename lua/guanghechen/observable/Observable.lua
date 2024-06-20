local BatchDisposable = require("guanghechen.disposable.BatchDisposable")
local Subscribers = require("guanghechen.subscriber.Subscribers")
local util_comparator = require("guanghechen.util.comparator")
local util_misc = require("guanghechen.util.misc")

---@class guanghechen.observable.Observable : guanghechen.types.IObservable
---@field private _subscribers guanghechen.types.ISubscribers
local Observable = {}
Observable.__index = Observable
setmetatable(Observable, { __index = BatchDisposable })

---@class guanghechen.observable.Observable.IOptions
---@field public equals? guanghechen.types.IEquals  Determine whether the two values are equal.

---@param default_value guanghechen.types.T
---@param options? guanghechen.observable.Observable.IOptions
---@return guanghechen.observable.Observable
function Observable.new(default_value, options)
  options = options or {}
  ---@cast options guanghechen.observable.Observable.IOptions

  ---@type guanghechen.types.IEquals
  local equals = options.equals and options.equals or util_comparator.shallow_equals

  local self = setmetatable(BatchDisposable.new(), Observable)

  ---@diagnostic disable-next-line: cast-type-mismatch
  ---@cast self guanghechen.observable.Observable

  ---@type guanghechen.types.ISubscribers
  self._subscribers = Subscribers.new()

  ---@type guanghechen.types.T
  self._value = default_value

  ---@type guanghechen.types.T | nil
  self._value_last_notified = nil

  ---@type guanghechen.types.IEquals
  self.equals = equals

  return self
end

function Observable:get_snapshot()
  return self._value
end

---@return nil
function Observable:dispose()
  if self:isDisposed() then
    return
  end

  BatchDisposable.dispose(self)

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
      error("Don't update a disposed observable. value: " .. vim.inspect(value))
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
---@return guanghechen.types.IUnsubscribable
function Observable:subscribe(subscriber)
  if subscriber:isDisposed() then
    return util_misc.noop_unsubscribable
  end

  ---@type guanghechen.types.T | nil
  local value_prev = self._value_last_notified

  ---@type guanghechen.types.T
  local value = self._value

  if self:isDisposed() then
    subscriber:next(value, value_prev)
    subscriber:dispose()
    return util_misc.noop_unsubscribable
  end

  subscriber:next(value, value_prev)
  return self._subscribers:subscribe(subscriber)
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
