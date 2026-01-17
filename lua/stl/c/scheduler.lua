---@diagnostic disable: invisible
---@diagnostic disable-next-line: unused-local
local __module_name__ = "stl.c.scheduler" ---@type string

---@alias stl.c.scheduler.IModeEnum
---| "debounce"
---| "throttle"

---@alias stl.c.scheduler.ITaskCallback
---| fun(ok: boolean, result: unknown|nil): nil

---@alias stl.c.scheduler.ITask
---| fun(scheduler: stl.c.Scheduler, context: unknown|nil, callback: stl.c.scheduler.ITaskCallback): unknown|nil

---@class stl.c.scheduler.IScheduleOpts
---@field public immediate              ?boolean
---@field public rescheduled            ?boolean
---@field public context                ?unknown

---@class stl.c.scheduler.IProps
---@field public name                   string
---@field public mode                   stl.c.scheduler.IModeEnum
---@field public task                   stl.c.scheduler.ITask
---@field public value                  stl.c.Observable
---@field public delay                  integer
---@field public timeout                integer
---@field public silent                 ?fun(): boolean
---@field public token                  ?stl.c.CancellationToken

---@class stl.c.Scheduler
---@field public fullname               string
---@field public mode                   stl.c.scheduler.IModeEnum
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
---@field protected _task               stl.c.scheduler.ITask
---
---@field protected _context            ?unknown
---@field protected _value              stl.c.Observable
---@field protected _token              ?stl.c.CancellationToken
---@field protected _token_sub          ?stl.c.IUnsubscribable
local M = {}
M.__index = M

---@param props                         stl.c.scheduler.IProps
---@return stl.c.Scheduler
function M.new(props)
  local timer_task = vim.uv.new_timer()
  local timer_timeout = vim.uv.new_timer()

  assert(timer_task ~= nil)
  assert(timer_timeout ~= nil)

  local name = props.name ---@type string
  local fullname = string.format("%s -> %s", name, __module_name__) ---@type string
  local mode = props.mode ---@type stl.c.scheduler.IModeEnum
  local task = props.task ---@type stl.c.scheduler.ITask
  local value = props.value ---@type stl.c.Observable
  local delay = props.delay ---@type integer
  local timeout = props.timeout ---@type integer
  local silent = props.silent or stl.fn.falsy ---@type fun(): boolean

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
  self._token = props.token or nil
  self._token_sub = nil

  -- Subscribe to token cancellation
  if self._token then
    self._token_sub = self._token:on_cancel(function()
      self:cancel()
    end)
  end

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

  -- Unsubscribe from token
  if self._token_sub then
    self._token_sub:unsubscribe()
    self._token_sub = nil
  end

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
  self._token = nil
end

---@return boolean
function M:isdisposed()
  return self._disposed
end

---@param opts                          ?stl.c.scheduler.IScheduleOpts
---@return stl.c.Scheduler
function M:schedule(opts)
  self:__health__()

  opts = opts or {} ---@type stl.c.scheduler.IScheduleOpts
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

---Schedule and return a Future that resolves when the task completes.
---@param opts                          ?stl.c.scheduler.IScheduleOpts
---@param token                         ?stl.c.CancellationToken
---@return stl.c.Future
function M:schedule_future(opts, token)
  self:__health__()

  local future = stl.c.Future.new({ token = token or self._token })
  if token and token:is_cancelled() then
    return future
  end

  -- Store original callback context
  local original_task = self._task
  local tick_at_schedule = self._tick_pending + 1

  -- Wrap task to capture result for this specific schedule call
  self._task = function(scheduler, context, callback)
    local result = original_task(scheduler, context, function(ok, res)
      callback(ok, res)
      -- Only resolve if this is the tick we scheduled
      if scheduler._tick_settled >= tick_at_schedule and not future:is_done() then
        if ok then
          future:__resolve__(res) ---@diagnostic disable-line: invisible
        else
          future:__reject__(res or "Task failed") ---@diagnostic disable-line: invisible
        end
      end
    end)
    return result
  end

  self:schedule(opts)

  -- Restore original task after scheduling
  self._task = original_task

  return future
end

----------------------------------------------------------------------------------------------------

---@protected
---@return table
function M:__details__()
  local fullname = self.fullname ---@type string
  local mode = self.mode ---@type stl.c.scheduler.IModeEnum
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
          if not silent then
            local fullname = self.fullname ---@type string
            stl.reporter.error({
              from = fullname,
              message = "failed to run.",
              details = {
                ctx = self:__details__(),
                error = result,
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

  callback = vim.schedule_wrap(callback) ---@type stl.c.scheduler.ITaskCallback

  vim.schedule(function()
    local task = self._task ---@type stl.c.scheduler.ITask
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
---@return stl.c.Scheduler
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
---@return stl.c.Scheduler
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
