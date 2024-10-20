local BatchDisposable = require("eve.collection.batch_disposable")
local Subscribers = require("eve.collection.subscribers")
local reporter = require("eve.std.reporter")
local std_boolean = require("eve.std.boolean")
local shallow_equals = require("eve.std.equals").shallow_equals
local util = require("eve.std.util")

---@class eve.collection.Observable : t.eve.collection.IObservable
---@field private _value                t.eve.T
---@field private _value_last_notified  t.eve.T|nil
---@field private _subscribers          t.eve.collection.ISubscribers
local M = {}
M.__index = M
setmetatable(M, { __index = BatchDisposable })

---@type t.eve.collection.IUnsubscribable
local noop_unsubscribable = {
  unsubscribe = function(...) end,
}

---@class eve.collection.observable.IProps
---@field public initial_value          t.eve.T           Initial value of the observable
---@field public equals                 ?t.eve.IEquals    Determine whether the two values are equal.
---@field public normalize              ?t.eve.INormalize Normalize the value before compare or update

---@param props                         eve.collection.observable.IProps
---@return eve.collection.Observable
function M.new(props)
  local equals = props.equals or shallow_equals ---@type t.eve.IEquals
  local normalize = props.normalize or util.identity ---@type t.eve.INormalize
  local initial_value = props.initial_value ---@type t.eve.T

  local self = setmetatable(BatchDisposable.new(), M)
  ---@cast self eve.collection.Observable

  self.equals = equals
  self.normalize = normalize
  self._value = normalize(initial_value)
  self._value_last_notified = nil
  self._subscribers = Subscribers.new()

  return self
end

---@param value                         t.eve.T         Initial value of the observable
---@param equals                        ?t.eve.IEquals  Determine whether the two values are equal.
---@param normalize                     ?t.eve.INormalize Normalize the value before compare or update
---@return eve.collection.Observable
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

---@param value t.eve.T
---@param options? t.eve.collection.IObservableNextOptions
---@return boolean Indicate whether if the value changed.
function M:next(value, options)
  options = options or {}
  ---@cast options t.eve.collection.IObservableNextOptions

  if self:is_disposed() then
    ---@type boolean
    local strict = std_boolean.cover(options.strict, true)
    if strict then
      reporter.error({
        from = "eve.collection.observable",
        subject = "next",
        message = "Don't update a disposed observable.",
        details = { value = value },
      })
    end
    return false
  end

  value = self.normalize(value)

  ---@type boolean
  local force = std_boolean.cover(options.force, false)
  if force or not self.equals(value, self._value) then
    self._value = value
    self:_notify()
    return true
  end
  return false
end

---@param subscriber                    t.eve.collection.ISubscriber
---@param ignoreInitial                 boolean
---@return t.eve.collection.IUnsubscribable
function M:subscribe(subscriber, ignoreInitial)
  if subscriber:is_disposed() then
    return noop_unsubscribable
  end

  if not ignoreInitial then
    local value_prev = self._value_last_notified ---@type t.eve.T | nil
    local value = self._value ---@type t.eve.T
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
  ---@type t.eve.T | nil
  local value_prev = self._value_last_notified

  ---@type t.eve.T
  local value = self._value

  self._value_last_notified = value

  vim.schedule(function()
    self._subscribers:notify(value, value_prev)
  end)
end

return M
