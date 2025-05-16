local __module_name__ = "std.collection.observable" ---@type string

---@class std.collection.observable.INextOptions
---@field public strict                 ?boolean Whether to throw an error if the observable disposed.
---@field public force                  ?boolean  Force trigger the notification of subscribers even the next value is equals to the current value.
---@field public silent                 ?boolean  Whether to notify the subscribers or not.

---@class std.collection.IObservable: std.collection.IBatchDisposable, std.collection.ISubscribable
---@field public equals                 std.t.IEquals
---@field public normalize              std.t.INormalize
---@field public snapshot               fun(self: std.collection.IObservable): std.t.T
---@field public next                   fun(self: std.collection.IObservable, value: std.t.T, options?: std.collection.observable.INextOptions):boolean

---@class std.collection.observable.IProps
---@field public initial_value          std.t.T           Initial value of the observable
---@field public equals                 ?std.t.IEquals    Determine whether the two values are equal.
---@field public normalize              ?std.t.INormalize Normalize the value before compare or update
---@field public readonly               ?boolean

---@type std.collection.IUnsubscribable
local noop_unsubscribable = { unsubscribe = std.fn.noop }

---@class std.collection.Observable : std.collection.IObservable
---@field private _readonly             boolean
---@field private _value                std.t.T
---@field private _value_last_notified  std.t.T|nil
---@field private _subscribers          std.collection.ISubscribers
---@diagnostic disable-next-line: assign-type-mismatch
local M = {}
M.__index = M
setmetatable(M, std.BatchDisposable)

---@param props                         std.collection.observable.IProps
---@return std.collection.Observable
function M.new(props)
  local equals = props.equals or std.fn.equals_shallow ---@type std.t.IEquals
  local normalize = props.normalize or std.fn.identity ---@type std.t.INormalize
  local readonly = not not props.readonly ---@type boolean
  local initial_value = props.initial_value ---@type std.t.T

  local self = setmetatable(std.BatchDisposable.new(), M)
  ---@cast self                         std.collection.Observable

  self.equals = equals
  self.normalize = normalize
  self._readonly = readonly
  self._value = normalize(initial_value)
  self._value_last_notified = nil
  self._subscribers = std.Subscribers.new()
  return self
end

---@param value                         std.t.T         Initial value of the observable
---@param equals                        ?std.t.IEquals  Determine whether the two values are equal.
---@param normalize                     ?std.t.INormalize Normalize the value before compare or update
---@return std.collection.Observable
function M.from_value(value, equals, normalize)
  return M.new({ initial_value = value, equals = equals, normalize = normalize })
end

function M:snapshot()
  return self._value
end

---@return nil
function M:dispose()
  if self:isdisposed() then
    return
  end

  std.BatchDisposable.dispose(self)

  -- Dispose subscribers
  self._subscribers:dispose()
end

---@param value                         std.t.T
---@param options                       ?std.collection.observable.INextOptions
---@return boolean Indicate whether if the value changed.
function M:next(value, options)
  if self._readonly then
    return false
  end

  options = options or {} ---@type std.collection.observable.INextOptions
  if self:isdisposed() then
    local strict = options.strict ~= false ---@type boolean
    if strict then
      std.reporter.error({
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

    local silent = not not options.silent ---@type boolean
    if not silent then
      self:_notify()
    end
    return true
  end
  return false
end

---@param subscriber                    std.collection.ISubscriber
---@param ignoreInitial                 boolean
---@return std.collection.IUnsubscribable
function M:subscribe(subscriber, ignoreInitial)
  if subscriber:isdisposed() then
    return noop_unsubscribable
  end

  if not ignoreInitial then
    local value_prev = self._value_last_notified ---@type std.t.T | nil
    local value = self._value ---@type std.t.T
    subscriber:next(value, value_prev)
  end

  if self:isdisposed() then
    subscriber:dispose()
    return noop_unsubscribable
  end

  return self._subscribers:subscribe(subscriber, ignoreInitial)
end

---@return nil
function M:_notify()
  ---@type std.t.T | nil
  local value_prev = self._value_last_notified

  ---@type std.t.T
  local value = self._value

  self._value_last_notified = value

  vim.schedule(function()
    self._subscribers:notify(value, value_prev)
  end)
end

return M
