local __module_name__ = "ark.c.observable" ---@type string

---@class ark.c.observable.INextOptions
---@field public strict                 ?boolean Whether to throw an error if the observable disposed.
---@field public force                  ?boolean  Force trigger the notification of subscribers even the next value is equals to the current value.
---@field public silent                 ?boolean  Whether to notify the subscribers or not.

---@class ark.c.observable.IProps
---@field public initial_value          ark.t.T           Initial value of the observable
---@field public equals                 ?ark.t.IEquals    Determine whether the two values are equal.
---@field public normalize              ?ark.t.INormalize Normalize the value before compare or update
---@field public readonly               ?boolean

---@type ark.c.IUnsubscribable
local noop_unsubscribable = { unsubscribe = ark.fn.noop }

---@class ark.c.Observable : ark.c.BatchDisposable, ark.c.ISubscribable
---@field public equals                 ark.t.IEquals
---@field public normalize              ark.t.INormalize
---@field protected _readonly           boolean
---@field protected _value              ark.t.T
---@field protected _value_last_notified ark.t.T|nil
---@field protected _subscribers        ark.c.Subscribers
---@diagnostic disable-next-line: assign-type-mismatch
local M = {}
M.__index = M
setmetatable(M, ark.c.BatchDisposable)

---@param props                         ark.c.observable.IProps
---@return ark.c.Observable
function M.new(props)
  local equals = props.equals or ark.fn.equals_shallow ---@type ark.t.IEquals
  local normalize = props.normalize or ark.fn.identity ---@type ark.t.INormalize
  local readonly = not not props.readonly ---@type boolean
  local initial_value = props.initial_value ---@type ark.t.T

  local self = setmetatable(ark.c.BatchDisposable.new(), M)
  ---@cast self                         ark.c.Observable

  self.equals = equals
  self.normalize = normalize
  self._readonly = readonly
  self._value = normalize(initial_value)
  self._value_last_notified = nil
  self._subscribers = ark.c.Subscribers.new()
  return self
end

---@param value                         ark.t.T         Initial value of the observable
---@param equals                        ?ark.t.IEquals  Determine whether the two values are equal.
---@param normalize                     ?ark.t.INormalize Normalize the value before compare or update
---@return ark.c.Observable
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

  ark.c.BatchDisposable.dispose(self)

  -- Dispose subscribers
  self._subscribers:dispose()
end

---@param value                         ark.t.T
---@param options                       ?ark.c.observable.INextOptions
---@return boolean Indicate whether if the value changed.
function M:next(value, options)
  if self._readonly then
    return false
  end

  options = options or {} ---@type ark.c.observable.INextOptions
  if self:isdisposed() then
    local strict = options.strict ~= false ---@type boolean
    if strict then
      ark.reporter.error({
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
      self:__notify__()
    end
    return true
  end
  return false
end

---@param subscriber                    ark.c.ISubscriber
---@param ignoreInitial                 boolean
---@return ark.c.IUnsubscribable
function M:subscribe(subscriber, ignoreInitial)
  if subscriber:isdisposed() then
    return noop_unsubscribable
  end

  if not ignoreInitial then
    local value_prev = self._value_last_notified ---@type ark.t.T | nil
    local value = self._value ---@type ark.t.T
    subscriber:next(value, value_prev)
  end

  if self:isdisposed() then
    subscriber:dispose()
    return noop_unsubscribable
  end

  return self._subscribers:subscribe(subscriber)
end

----------------------------------------------------------------------------------------------------

---@protected
---@return nil
function M:__notify__()
  ---@type ark.t.T | nil
  local value_prev = self._value_last_notified

  ---@type ark.t.T
  local value = self._value

  self._value_last_notified = value

  vim.schedule(function()
    self._subscribers:notify(value, value_prev)
  end)
end

return M
