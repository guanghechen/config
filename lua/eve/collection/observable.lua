local BatchDisposable = require("eve.collection.batch_disposable")
local Subscribers = require("eve.collection.subscribers")
local reporter = require("eve.std.reporter")
local std_boolean = require("eve.std.boolean")
local util = require("eve.std.util")

---@class eve.collection.Observable : eve.types.collection.IObservable
---@field private _value                eve.types.T
---@field private _value_last_notified  eve.types.T|nil
---@field private _subscribers          eve.types.collection.ISubscribers
local M = {}
M.__index = M
setmetatable(M, { __index = BatchDisposable })

---@type eve.types.collection.IUnsubscribable
local noop_unsubscribable = {
  unsubscribe = function(...) end,
}

---@generic T
---@param x T
---@param y T
---@return boolean
local function shallow_equals(x, y)
  return x == y
end

---@class eve.collection.observable.IProps
---@field public initial_value          eve.types.T           Initial value of the observable
---@field public equals                 ?eve.types.IEquals    Determine whether the two values are equal.
---@field public normalize              ?eve.types.INormalize Normalize the value before compare or update

---@param props                         eve.collection.observable.IProps
---@return eve.collection.Observable
function M.new(props)
  local equals = props.equals or shallow_equals ---@type eve.types.IEquals
  local normalize = props.normalize or util.identity ---@type eve.types.INormalize
  local initial_value = props.initial_value ---@type eve.types.T

  local self = setmetatable(BatchDisposable.new(), M)
  ---@cast self eve.collection.Observable

  self.equals = equals
  self.normalize = normalize
  self._value = normalize(initial_value)
  self._value_last_notified = nil
  self._subscribers = Subscribers.new()

  return self
end

---@param value                         eve.types.T         Initial value of the observable
---@param equals                        ?eve.types.IEquals  Determine whether the two values are equal.
---@param normalize                     ?eve.types.INormalize Normalize the value before compare or update
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

---@param value eve.types.T
---@param options? eve.types.collection.IObservableNextOptions
---@return boolean Indicate whether if the value changed.
function M:next(value, options)
  options = options or {}
  ---@cast options eve.types.collection.IObservableNextOptions

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

---@param subscriber                    eve.types.collection.ISubscriber
---@param ignoreInitial                 boolean
---@return eve.types.collection.IUnsubscribable
function M:subscribe(subscriber, ignoreInitial)
  if subscriber:is_disposed() then
    return noop_unsubscribable
  end

  if not ignoreInitial then
    local value_prev = self._value_last_notified ---@type eve.types.T | nil
    local value = self._value ---@type eve.types.T
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
  ---@type eve.types.T | nil
  local value_prev = self._value_last_notified

  ---@type eve.types.T
  local value = self._value

  self._value_last_notified = value

  vim.schedule(function()
    self._subscribers:notify(value, value_prev)
  end)
end

return M
