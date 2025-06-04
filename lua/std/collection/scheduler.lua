local __module_name__ = "std.collection.scheduler" ---@type string

---@alias std.collection.scheduler.ScheduleModeEnum
---| "debounce"
---| "throttle"

---@alias std.collection.scheduler.ITaskCallback
---| fun(ok: boolean, result: unknown|nil): nil

---@alias std.collection.scheduler.ITask
---| fun(scheduler: std.collection.Scheduler, context: unknown|nil, callback: std.collection.scheduler.ITaskCallback): unknown|nil

---@class std.collection.scheduler.IScheduleOpts
---@field public immediate              ?boolean
---@field public rescheduled            ?boolean
---@field public context                ?unknown

---@class std.collection.scheduler.IProps
---@field public name                   string
---@field public mode                   std.collection.scheduler.ScheduleModeEnum
---@field public task                   std.collection.scheduler.ITask
---@field public value                  std.collection.IObservable
---@field public delay                  integer
---@field public timeout                integer
---@field public silent                 ?fun(): boolean

---@class std.collection.Scheduler
---@field public fullname               string
---@field public mode                   std.collection.scheduler.ScheduleModeEnum
---
---@field protected _disposed           boolean
---@field protected _timer_task         uv.uv_timer_t
---@field protected _timer_timeout      uv.uv_timer_t
---@field protected _tick_freezed       integer
---@field protected _tick_pending       integer
---@field protected _tick_running       integer
---@field protected _tick_settled       integer
---
---@field protected _delay              integer
---@field protected _timeout            integer
---
---@field protected _silent             fun(): boolean
---@field protected _task               std.collection.scheduler.ITask
---
---@field protected _context            unknown|nil
---@field protected _value              std.collection.IObservable
local M = {}
M.__index = M

---@param props                         std.collection.scheduler.IProps
---@return std.collection.Scheduler
function M.new(props)
  local timer_task = vim.uv.new_timer()
  local timer_timeout = vim.uv.new_timer()

  assert(timer_task ~= nil)
  assert(timer_timeout ~= nil)

  local name = props.name ---@type string
  local fullname = string.format("%s -> %s", name, __module_name__) ---@type string
  local mode = props.mode ---@type std.collection.scheduler.ScheduleModeEnum
  local task = props.task ---@type std.collection.scheduler.ITask
  local value = props.value ---@type std.collection.IObservable
  local delay = props.delay ---@type integer
  local timeout = props.timeout ---@type integer
  local silent = props.silent or std.fn.falsy ---@type fun(): boolean

  local self = setmetatable({}, M)
  self.fullname = fullname
  self.mode = mode

  self._disposed = false
  self._timer_task = timer_task
  self._timer_timeout = timer_timeout
  self._tick_freezed = 0
  self._tick_pending = 0
  self._tick_running = 0
  self._tick_settled = 0

  self._delay = delay
  self._timeout = timeout

  self._task = task
  self._silent = silent

  self._context = nil
  self._value = value
  return self
end

---@return nil
function M:cancel()
  self:__health__()

  self._timer_task:stop()
  self._timer_timeout:stop()

  local tick = self._tick_pending + 1 ---@type integer
  self._tick_freezed = tick ---@type integer
  self._tick_pending = tick ---@type integer
  self._tick_running = tick ---@type integer
  self._tick_settled = tick ---@type integer
end

---@return nil
function M:dispose()
  if self._disposed then
    return
  end
  self._disposed = true

  self._timer_task:stop()
  self._timer_task:close()
  self._timer_timeout:stop()
  self._timer_timeout:close()

  self._timer_task = nil
  self._timer_timeout = nil
  self._tick_freezed = 0
  self._tick_pending = 0
  self._tick_running = 0
  self._tick_settled = 0

  self._delay = 0
  self._silent = nil
  self._timeout = 0

  self._context = nil
  self._value = nil
end

---@return boolean
function M:isdisposed()
  return self._disposed
end

---@param opts                          ?std.collection.scheduler.IScheduleOpts
---@return std.collection.Scheduler
function M:schedule(opts)
  self:__health__()

  opts = opts or {} ---@type std.collection.scheduler.IScheduleOpts
  local immediate = not not opts.immediate ---@type boolean
  local rescheduled = not not opts.rescheduled ---@type boolean
  local context = opts.context ---@type unknown|nil

  self._context = context
  if not rescheduled then
    self._tick_pending = self._tick_pending + 1 ---@type integer
  end

  if self.mode == "debounce" then
    return self:__schedule_debounce__(immediate)
  end

  if self.mode == "throttle" then
    return self:__schedule_throttle__(immediate)
  end

  error(string.format("[%s] Invalid schedule mode: %s", self.fullname, self.mode))
end

---@return unknown|nil
function M:snapshot()
  self:__health__()
  return self._value:snapshot()
end

---@protected
---@return table
function M:__details__()
  local fullname = self.fullname ---@type string
  local mode = self.mode ---@type std.collection.scheduler.ScheduleModeEnum
  local context = self._context ---@type unknown|nil
  local disposed = self._disposed ---@type boolean
  local tick_freezed = self._tick_freezed ---@type integer
  local tick_pending = self._tick_pending ---@type integer
  local tick_running = self._tick_running ---@type integer
  local tick_settled = self._tick_settled ---@type integer

  local delay = self._delay ---@type integer
  local timeout = self._timeout ---@type integer
  local silent = self._silent() ---@type boolean
  local value = self._value:snapshot() ---@type unknown|nil

  return {
    fullname = fullname,
    mode = mode,
    context = context,
    disposed = disposed,
    tick = {
      freezed = tick_freezed,
      pending = tick_pending,
      running = tick_running,
      settled = tick_settled,
    },
    delay = delay,
    timeout = timeout,
    silent = silent,
    value = value,
  }
end

---@protected
---@return nil
function M:__health__()
  if self._disposed then
    local message = string.format("[%s] already been disposed.", self.fullname) ---@type string
    error(message)
  end
end

---@protected
---@return nil
function M:__run__()
  if self._disposed then
    return
  end

  local tick = self._tick_pending ---@type integer
  if tick <= self._tick_running then
    return
  end
  self._tick_running = tick

  local settled = false ---@type boolean
  local context = self._context ---@type unknown|nil

  ---@param ok                          boolean
  ---@param result                      unknown
  ---@return nil
  local function callback(ok, result)
    if settled or self._disposed then
      return
    end
    settled = true

    if tick > self._tick_settled then
      self._tick_settled = tick

      if ok then
        self._value:next(result)
      else
        if result ~= nil then
          local silent = self._silent() ---@type boolean
          if silent then
            local fullname = self.fullname ---@type string
            std.reporter.error({
              from = fullname,
              message = "failed to run.",
              details = {
                ctx = self:__details__(),
                result = result,
              },
            })
          end
        end
      end
    end

    if tick == self._tick_running and tick < self._tick_pending then
      self:schedule({ rescheduled = true })
    end
  end

  callback = vim.schedule_wrap(callback) ---@type std.collection.scheduler.ITaskCallback

  vim.schedule(function()
    local task = self._task ---@type std.collection.scheduler.ITask
    local ok, result = pcall(task, self, context, callback)

    local timeout = self._timeout ---@type integer
    if timeout == 0 or not ok or result ~= nil then
      callback(ok, result)
      return
    end

    self._timer_timeout:start(timeout, 0, function()
      callback(false, "cancelled -- timed out")
    end)
  end)
end

---@protected
---@param immediate                     boolean
---@return std.collection.Scheduler
function M:__schedule_debounce__(immediate)
  if immediate then
    self._timer_timeout:stop()
    self._timer_task:stop()
    self:__run__()
    return self
  end

  self._timer_timeout:stop()
  self._timer_task:start(self._delay, 0, function()
    self:__run__()
  end)
  return self
end

---@protected
---@param immediate                     boolean
---@return std.collection.Scheduler
function M:__schedule_throttle__(immediate)
  local tick = self._tick_pending ---@type integer

  if immediate then
    self._tick_freezed = self._tick_settled
    self._timer_timeout:stop()
    self._timer_task:start(self._delay, 0, function()
      self._tick_freezed = tick
      self:schedule({ rescheduled = true })
    end)
    self:__run__()
    return self
  end

  if self._tick_running == self._tick_freezed and self._tick_running == self._tick_settled then
    self._timer_timeout:stop()
    self._timer_task:start(self._delay, 0, function()
      self._tick_freezed = tick
      self:schedule({ rescheduled = true })
    end)
    self:__run__()
  end
  return self
end

return M
