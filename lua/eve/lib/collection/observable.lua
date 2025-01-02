local __module_name__ = "eve.lib.collection.observable" ---@type string

local reporter = require("eve.builtin.reporter")

local functional = require("eve.lib.functional")
local BatchDisposable = require("eve.lib.collection.batch_disposable")
local Subscribers = require("eve.lib.collection.subscribers")

---@class eve.lib.collection.observable.INextOptions
---@field public strict                 ?boolean Whether to throw an error if the observable disposed.
---@field public force                  ?boolean  Force trigger the notification of subscribers even the next value is equals to the current value.

---@class eve.lib.collection.IObservable: eve.lib.collection.IBatchDisposable, eve.lib.collection.ISubscribable
---@field public equals                 eve.t.IEquals
---@field public normalize              eve.t.INormalize
---@field public snapshot               fun(self: eve.lib.collection.IObservable): eve.t.T
---@field public next                   fun(self: eve.lib.collection.IObservable, value: eve.t.T, options?: eve.lib.collection.observable.INextOptions):boolean

---@class eve.lib.collection.observable.IProps
---@field public initial_value          eve.t.T           Initial value of the observable
---@field public equals                 ?eve.t.IEquals    Determine whether the two values are equal.
---@field public normalize              ?eve.t.INormalize Normalize the value before compare or update

---@type eve.lib.collection.IUnsubscribable
local noop_unsubscribable = { unsubscribe = functional.noop }

---@class eve.lib.collection.Observable : eve.lib.collection.IObservable
---@field private _value                eve.t.T
---@field private _value_last_notified  eve.t.T|nil
---@field private _subscribers          eve.lib.collection.ISubscribers
---@diagnostic disable-next-line: assign-type-mismatch
local M = {}
M.__index = M
setmetatable(M, BatchDisposable)

---@param props                         eve.lib.collection.observable.IProps
---@return eve.lib.collection.Observable
function M.new(props)
  local equals = props.equals or functional.equals_shallow ---@type eve.t.IEquals
  local normalize = props.normalize or functional.identity ---@type eve.t.INormalize
  local initial_value = props.initial_value ---@type eve.t.T

  local self = setmetatable(BatchDisposable.new(), M)
  ---@cast self                         eve.lib.collection.Observable

  self.equals = equals
  self.normalize = normalize
  self._value = normalize(initial_value)
  self._value_last_notified = nil
  self._subscribers = Subscribers.new()

  return self
end

---@param value                         eve.t.T         Initial value of the observable
---@param equals                        ?eve.t.IEquals  Determine whether the two values are equal.
---@param normalize                     ?eve.t.INormalize Normalize the value before compare or update
---@return eve.lib.collection.Observable
function M.from_value(value, equals, normalize)
  return M.new({ initial_value = value, equals = equals, normalize = normalize })
end

function M:snapshot()
  return self._value
end

---@return nil
function M:dispose()
  if self:is_disposed() then
    return
  end

  BatchDisposable.dispose(self)

  -- Dispose subscribers
  self._subscribers:dispose()
end

---@param value eve.t.T
---@param options? eve.lib.collection.observable.INextOptions
---@return boolean Indicate whether if the value changed.
function M:next(value, options)
  options = options or {} ---@type eve.lib.collection.observable.INextOptions

  if self:is_disposed() then
    local strict = options.strict ~= false ---@type boolean
    if strict then
      reporter.error({
        from = __module_name__,
        subject = "next",
        message = "Don't update a disposed observable.",
        details = { value = value },
      })
    end
    return false
  end

  value = self.normalize(value)

  local force = not not options.force ---@type boolean
  if force or not self.equals(value, self._value) then
    self._value = value
    self:_notify()
    return true
  end
  return false
end

---@param subscriber                    eve.lib.collection.ISubscriber
---@param ignoreInitial                 boolean
---@return eve.lib.collection.IUnsubscribable
function M:subscribe(subscriber, ignoreInitial)
  if subscriber:is_disposed() then
    return noop_unsubscribable
  end

  if not ignoreInitial then
    local value_prev = self._value_last_notified ---@type eve.t.T | nil
    local value = self._value ---@type eve.t.T
    subscriber:next(value, value_prev)
  end

  if self:is_disposed() then
    subscriber:dispose()
    return noop_unsubscribable
  end

  return self._subscribers:subscribe(subscriber, ignoreInitial)
end

---@return nil
function M:_notify()
  ---@type eve.t.T | nil
  local value_prev = self._value_last_notified

  ---@type eve.t.T
  local value = self._value

  self._value_last_notified = value

  vim.schedule(function()
    self._subscribers:notify(value, value_prev)
  end)
end

return M
