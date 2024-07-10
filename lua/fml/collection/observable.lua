local BatchDisposable = require("fml.collection.batch_disposable")
local Subscribers = require("fml.collection.subscribers")
local reporter = require("fml.std.reporter")
local std_boolean = require("fml.std.boolean")

---@class fml.collection.Observable : fml.types.collection.IObservable
---@field private _value                fml.types.T
---@field private _value_last_notified  fml.types.T|nil
---@field private _subscribers          fml.types.collection.ISubscribers
local M = {}
M.__index = M
setmetatable(M, { __index = BatchDisposable })

---@type fml.types.collection.IUnsubscribable
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

---@generic T
---@param x T
---@return T
local function identity(x)
  return x
end

---@class fml.collection.observable.IProps
---@field public initial_value          fml.types.T           Initial value of the observable
---@field public equals                 ?fml.types.IEquals    Determine whether the two values are equal.
---@field public normalize              ?fml.types.INormalize Normalize the value before compare or update

---@param props                         fml.collection.observable.IProps
---@return fml.collection.Observable
function M.new(props)
  local equals = props.equals or shallow_equals ---@type fml.types.IEquals
  local normalize = props.normalize or identity ---@type fml.types.INormalize
  local initial_value = props.initial_value ---@type fml.types.T

  local self = setmetatable(BatchDisposable.new(), M)
  ---@cast self fml.collection.Observable

  self.equals = equals
  self.normalize = normalize
  self._value = normalize(initial_value)
  self._value_last_notified = nil
  self._subscribers = Subscribers.new()

  return self
end

---@param value                         fml.types.T         Initial value of the observable
---@param equals                        ?fml.types.IEquals  Determine whether the two values are equal.
---@param normalize                     ?fml.types.INormalize Normalize the value before compare or update
---@return fml.collection.Observable
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

---@param value fml.types.T
---@param options? fml.types.collection.IObservableNextOptions
---@return boolean Indicate whether if the value changed.
function M:next(value, options)
  options = options or {}
  ---@cast options fml.types.collection.IObservableNextOptions

  if self:is_disposed() then
    ---@type boolean
    local strict = std_boolean.cover(options.strict, true)
    if strict then
      reporter.error({
        from = "fml.collection.observable",
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

---@param subscriber fml.types.collection.ISubscriber
---@return fml.types.collection.IUnsubscribable
function M:subscribe(subscriber)
  if subscriber:is_disposed() then
    return noop_unsubscribable
  end

  ---@type fml.types.T | nil
  local value_prev = self._value_last_notified

  ---@type fml.types.T
  local value = self._value

  if self:is_disposed() then
    subscriber:next(value, value_prev)
    subscriber:dispose()
    return noop_unsubscribable
  end

  subscriber:next(value, value_prev)
  return self._subscribers:subscribe(subscriber)
end

---@return nil
function M:_notify()
  ---@type fml.types.T | nil
  local value_prev = self._value_last_notified

  ---@type fml.types.T
  local value = self._value

  self._value_last_notified = value

  vim.schedule(function()
    self._subscribers:notify(value, value_prev)
  end)
end

return M
