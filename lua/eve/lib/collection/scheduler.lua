local __module_name__ = "eve.lib.collection.scheduler" ---@type string

local reporter = require("eve.lib.reporter")

---@class eve.lib.collection.IScheduler
---@field public name                   string
---@field public cancel                 fun(self: eve.lib.collection.IScheduler): nil
---@field public mark_dirty             fun(self: eve.lib.collection.IScheduler): nil
---@field public schedule               fun(self: eve.lib.collection.IScheduler): nil
---@field public snapshot               fun(self: eve.lib.collection.IScheduler): unknown|nil

---@alias eve.lib.collection.scheduler.ITask
---| fun(callback: eve.lib.collection.promise.IOnFinally): nil

---@class eve.lib.collection.scheduler.IProps
---@field public name                   string
---@field public delay                  ?integer
---@field public silent                 ?boolean
---@field public task                   eve.lib.collection.scheduler.ITask

---@class eve.lib.collection.Scheduler : eve.lib.collection.IScheduler
---@field public name                   string
---
---@field protected _delay              integer
---@field protected _immediate          boolean
---@field protected _silent             boolean
---
---@field protected _result             unknown|nil
---@field protected _task               eve.lib.collection.scheduler.ITask
---
---@field protected _tick_alive         integer
---@field protected _tick_dirty         integer
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

  self.name = name

  self._delay = delay
  self._immediate = false
  self._silent = silent

  self._result = nil
  self._task = task

  self._tick_alive = 0
  self._tick_dirty = 1
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
function M:mark_dirty()
  self._tick_dirty = self._tick_scheduled
end

---@return nil
function M:schedule()
  local delay = self._tick_dirty > self._tick_resolved and 0 or self._delay ---@type integer
  local tick = self._tick_scheduled + 1 ---@type integer
  self._tick_scheduled = tick

  vim.defer_fn(function()
    self:execute()
  end, delay)
end

---@return unknown|nil
function M:snapshot()
  return self._result
end

---@return nil
function M:execute()
  local tick = self._tick_scheduled ---@type integer

  if tick < self._tick_alive then
    return
  end

  if self._tick_settled < self._tick_resolving then
    self._immediate = true
    return
  end

  if tick <= self._tick_resolving then
    return
  end

  local finished = false ---@type boolean

  ---@param settled                     eve.lib.collection.promise.ISettled
  ---@param value                       unknown
  ---@param reason                      unknown
  ---@return nil
  local function callback(settled, value, reason)
    if finished then
      return
    end

    finished = true

    if settled == "fulfilled" then
      if self._tick_resolved < tick then
        self._tick_resolved = tick
        self._result = value
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
            tick_dirty = self._tick_dirty,
            tick_scheduled = self._tick_scheduled,
            tick_resolving = self._tick_resolving,
            tick_resolved = self._tick_settled,
            tick_settled = self._tick_settled,
          },
        })
      end
    end

    if self._tick_settled < tick then
      self._tick_settled = tick

      if self._immediate then
        self._immediate = false
        vim.schedule(function()
          self:execute()
        end)
      end
    end
  end

  self._tick_resolving = tick
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
