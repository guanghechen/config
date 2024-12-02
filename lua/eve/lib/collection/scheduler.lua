local __module_name__ = "eve.lib.collection.scheduler" ---@type string

local reporter = require("eve.lib.reporter")
local Observable = require("eve.lib.collection.observable")

---@class eve.lib.collection.IScheduler
---@field public name                   string
---@field public cancel                 fun(self: eve.lib.collection.IScheduler): nil
---@field public schedule               fun(self: eve.lib.collection.IScheduler): nil
---@field public snapshot               fun(self: eve.lib.collection.IScheduler): unknown|nil
---@field public subscribe              fun(self: eve.lib.collection.IScheduler, subscriber: eve.lib.collection.ISubscriber, ignoreInitial: boolean): eve.lib.collection.IUnsubscribable

---@alias eve.lib.collection.scheduler.ITask
---| fun(callback: eve.lib.collection.promise.IOnFinally): nil

---@class eve.lib.collection.scheduler.IProps
---@field public name                   string
---@field public delay                  ?integer
---@field public silent                 ?boolean
---@field public task                   eve.lib.collection.scheduler.ITask
---@field public equals                 ?fun(a: unknown, b: unknown): boolean

---@class eve.lib.collection.Scheduler : eve.lib.collection.IScheduler
---@field public name                   string
---
---@field protected _delay              integer
---@field protected _immediate          boolean
---@field protected _silent             boolean
---
---@field protected _task               eve.lib.collection.scheduler.ITask
---@field protected _value              eve.lib.collection.IObservable
---
---@field protected _tick_alive         integer
---@field protected _tick_scheduled     integer
---@field protected _tick_resolving     integer
---@field protected _tick_resolved      integer
---@field protected _tick_settled       integer
local M = {}
M.__index = M

---@param props                         eve.lib.collection.scheduler.IProps
---@return eve.lib.collection.Scheduler
function M.new(props)
  local self = setmetatable({}, M)

  local name = props.name ---@type string
  local silent = not not props.silent ---@type boolean
  local delay = props.delay or 32 ---@type integer
  local task = props.task ---@type eve.lib.collection.scheduler.ITask
  local equals = props.equals ---@type (fun(a: unknown, b: unknown): boolean)|nil

  self.name = name

  self._delay = delay
  self._immediate = false
  self._silent = silent

  self._task = task
  self._value = Observable.from_value(nil, equals)

  self._tick_alive = 0
  self._tick_scheduled = 1
  self._tick_resolving = 0
  self._tick_resolved = 0
  self._tick_settled = 0

  return self
end

---@return nil
function M:cancel()
  self._tick_alive = self._tick_scheduled + 1
end

---@return nil
function M:schedule()
  local tick = self._tick_scheduled + 1 ---@type integer
  self._tick_scheduled = tick

  if self._tick_settled < self._tick_resolving then
    self._immediate = true
    return
  end

  self:execute()
end

---@return unknown|nil
function M:snapshot()
  return self._value:snapshot()
end

---@param subscriber                    eve.lib.collection.ISubscriber
---@param ignoreInitial                 boolean
---@return eve.lib.collection.IUnsubscribable
function M:subscribe(subscriber, ignoreInitial)
  return self._value:subscribe(subscriber, ignoreInitial)
end

---@return nil
function M:execute()
  local tick = self._tick_scheduled ---@type integer

  if tick < self._tick_alive or tick <= self._tick_resolving then
    return
  end

  if self._tick_settled < self._tick_resolving then
    self._immediate = true
    return
  end

  self._tick_resolving = tick

  local callback_called = false ---@type boolean

  ---@param settled                     eve.lib.collection.promise.ISettled
  ---@param value                       unknown
  ---@param reason                      unknown
  ---@return nil
  local function callback(settled, value, reason)
    if callback_called then
      return
    end
    callback_called = true

    if settled == "fulfilled" then
      if self._tick_resolved < tick then
        self._tick_resolved = tick
        self._value:next(value)
      end
    elseif settled == "rejected" then
      if not self._silent then
        reporter.error({
          from = __module_name__,
          subject = "execute",
          message = "Task failed.",
          details = {
            name = self.name,
            reason = reason,

            tick = tick,
            tick_scheduled = self._tick_scheduled,
            tick_resolving = self._tick_resolving,
            tick_resolved = self._tick_settled,
            tick_settled = self._tick_settled,
          },
        })
      end
    end

    vim.defer_fn(function()
      if self._tick_settled < tick then
        self._tick_settled = tick

        if self._immediate then
          self._immediate = false
          self:execute()
        end
      end
    end, self._delay)
  end

  local ok, reasonOrResult = pcall(self._task, callback)
  if reasonOrResult ~= nil then
    if ok then
      callback("fulfilled", reasonOrResult, nil)
    else
      callback("rejected", nil, reasonOrResult)
    end
  end
end

return M
