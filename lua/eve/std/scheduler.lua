local reporter = require("eve.std.reporter")

---@class eve.std.scheduler
local M = {}

---@alias eve.std.scheduler.IScheduleCallback
---| fun(ok: boolean, result: t.eve.T|nil): nil

---@class eve.std.scheduler.ISchedulerProps
---@field public name                  string
---@field public fn                    fun(callback: eve.std.scheduler.IScheduleCallback): t.eve.T
---@field public callback              ?eve.std.scheduler.IScheduleCallback
---@field public delay                 ?integer

---@class eve.std.scheduler.IScheduler
---@field public schedule               fun(): nil
---@field public snapshot               fun(): t.eve.T
---@field public cancel                 fun(): nil

---@param params                        eve.std.scheduler.ISchedulerProps
---@return eve.std.scheduler.IScheduler
function M.debounce(params)
  local name = params.name ---@type string
  local fn = params.fn ---@type fun(callback: eve.std.scheduler.IScheduleCallback): t.eve.T
  local callback = params.callback ---@type eve.std.scheduler.IScheduleCallback|nil
  local delay = math.max(1, params.delay or 0) ---@type integer

  local _tick_call = 1 ---@type integer
  local _tick_resolved = 0 ---@type integer
  local _result = nil ---@type t.eve.T

  ---@return nil
  local function schedule()
    _tick_call = _tick_call + 1
    local tick_snapshot = _tick_call ---@type integer

    vim.defer_fn(function()
      if tick_snapshot == _tick_call then
        fn(function(ok, result)
          if _tick_resolved < tick_snapshot then
            if ok then
              _result = result
              _tick_resolved = tick_snapshot
            else
              reporter.error({
                from = "eve.std.scheduler",
                subject = "debounce.schedule",
                message = "Failed to run.",
                details = { name = name, result = result or "nil" },
              })
            end

            if callback ~= nil then
              callback(ok, result)
            end
          end
        end)
      end
    end, delay)
  end

  ---@return t.eve.T|nil
  local function snapshot()
    return _result
  end

  ---@return nil
  local function cancel()
    _tick_call = _tick_call + 1
  end

  ---@type eve.std.scheduler.IScheduler
  local scheduler = {
    schedule = schedule,
    snapshot = snapshot,
    cancel = cancel,
  }
  return scheduler
end

---@param params                        eve.std.scheduler.ISchedulerProps
---@return eve.std.scheduler.IScheduler
function M.throttle(params)
  local fn = params.fn ---@type fun(callback: eve.std.scheduler.IScheduleCallback): t.eve.T
  local callback = params.callback ---@type eve.std.scheduler.IScheduleCallback|nil
  local delay = math.max(1, params.delay or 0) ---@type integer

  local _scheduling = false ---@type boolean

  local _tick_call = 1 ---@type integer
  local _tick_alive = 0 ---@type integer
  local _tick_scheduled = 1 ---@type integer
  local _tick_resolved = 0 ---@type integer
  local _result = nil ---@type t.eve.T

  ---@return nil
  local function schedule()
    _tick_call = _tick_call + 1

    if _scheduling then
      return
    end

    _scheduling = true
    _tick_scheduled = _tick_call
    local tick_snapshot = _tick_call ---@type integer

    vim.defer_fn(function()
      _scheduling = false
      if _tick_call >= _tick_alive and _tick_call > _tick_scheduled then
        schedule()
      end

      if tick_snapshot >= _tick_alive then
        fn(function(ok, result)
          if _tick_resolved < tick_snapshot then
            if ok then
              _result = result
              _tick_resolved = tick_snapshot
            end

            if callback ~= nil then
              callback(ok, result)
            end
          end
        end)
      end
    end, delay)
  end

  ---@return t.eve.T|nil
  local function snapshot()
    return _result
  end

  ---@return nil
  local function cancel()
    _tick_alive = _tick_call + 1
  end

  ---@type eve.std.scheduler.IScheduler
  local scheduler = {
    schedule = schedule,
    snapshot = snapshot,
    cancel = cancel,
  }
  return scheduler
end

---@param name                          string
---@param fn                            fun(): nil
---@param timeout                       ?integer
---@return fun(): nil
function M.schedule(name, fn, timeout)
  local lock = false
  local dirty = true

  local wrapped ---@type fun(): nil
  wrapped = function()
    if lock then
      dirty = true
      return
    end

    lock = true
    dirty = false

    local function run()
      local ok, result = pcall(fn)
      if not ok then
        vim.notify(
          '[eve.std.scheduler] schedule: Failed to run "' .. name .. '".\n' .. vim.inspect({ result = result or "nil" })
        )
      end

      lock = false
      if dirty then
        dirty = false
        wrapped()
      end
    end

    if timeout ~= nil and timeout > 0 then
      vim.defer_fn(run, timeout)
    else
      vim.schedule(run)
    end
  end
  return wrapped
end

return M
