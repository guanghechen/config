local __module_name__ = "stl.c.observable" ---@type string

---@class stl.c.observable.INextOptions
---@field public strict                 ?boolean Whether to throw an error if the observable disposed.
---@field public force                  ?boolean  Force trigger the notification of subscribers even the next value is equals to the current value.
---@field public silent                 ?boolean  Whether to notify the subscribers or not.

---@class stl.c.observable.IProps
---@field public initial_value          stl.t.T           Initial value of the observable
---@field public equals                 ?stl.t.IEquals    Determine whether the two values are equal.
---@field public normalize              ?stl.t.INormalize Normalize the value before compare or update
---@field public readonly               ?boolean

---@type stl.c.IUnsubscribable
local noop_unsubscribable = { unsubscribe = stl.fn.noop }

---@class stl.c.Observable : stl.c.BatchDisposable, stl.c.ISubscribable
---@field public equals                 stl.t.IEquals
---@field public normalize              stl.t.INormalize
---@field protected _readonly           boolean
---@field protected _value              stl.t.T
---@field protected _value_last_notified stl.t.T|nil
---@field protected _subscribers        stl.c.Subscribers
---@diagnostic disable-next-line: assign-type-mismatch
local M = {}
M.__index = M
setmetatable(M, stl.c.BatchDisposable)

---@param props                         stl.c.observable.IProps
---@return stl.c.Observable
function M.new(props)
  local equals = props.equals or stl.fn.equals_shallow ---@type stl.t.IEquals
  local normalize = props.normalize or stl.fn.identity ---@type stl.t.INormalize
  local readonly = not not props.readonly ---@type boolean
  local initial_value = props.initial_value ---@type stl.t.T

  local self = setmetatable(stl.c.BatchDisposable.new(), M)
  ---@cast self                         stl.c.Observable

  self.equals = equals
  self.normalize = normalize
  self._readonly = readonly
  self._value = normalize(initial_value)
  self._value_last_notified = nil
  self._subscribers = stl.c.Subscribers.new()
  return self
end

---@param value                         stl.t.T         Initial value of the observable
---@param equals                        ?stl.t.IEquals  Determine whether the two values are equal.
---@param normalize                     ?stl.t.INormalize Normalize the value before compare or update
---@return stl.c.Observable
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

  stl.c.BatchDisposable.dispose(self)

  -- Dispose subscribers
  self._subscribers:dispose()
end

---@param value                         stl.t.T
---@param options                       ?stl.c.observable.INextOptions
---@return boolean Indicate whether if the value changed.
function M:next(value, options)
  if self._readonly then
    return false
  end

  options = options or {} ---@type stl.c.observable.INextOptions
  if self:isdisposed() then
    local strict = options.strict ~= false ---@type boolean
    if strict then
      stl.reporter.error({
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

---@param subscriber                    stl.c.ISubscriber
---@param ignoreInitial                 ?boolean
---@return stl.c.IUnsubscribable
function M:subscribe(subscriber, ignoreInitial)
  if subscriber:isdisposed() then
    return noop_unsubscribable
  end

  if not ignoreInitial then
    local value_prev = self._value_last_notified ---@type stl.t.T | nil
    local value = self._value ---@type stl.t.T
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
  ---@type stl.t.T | nil
  local value_prev = self._value_last_notified

  ---@type stl.t.T
  local value = self._value

  self._value_last_notified = value

  vim.schedule(function()
    self._subscribers:notify(value, value_prev)
  end)
end

return M
