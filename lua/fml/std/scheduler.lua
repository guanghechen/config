---@class fml.std.scheduler
local M = {}

---@alias fml.std.scheduler.IScheduleCallback
---| fun(ok: boolean, result: fml.types.T|nil): nil

---@class fml.std.scheduler.ISchedulerProps
---@field public fn                    fun(callback: fml.std.scheduler.IScheduleCallback): fml.types.T
---@field public callback              ?fml.std.scheduler.IScheduleCallback
---@field public delay                 ?integer

---@class fml.std.scheduler.IScheduler
---@field public schedule               fun(): nil
---@field public snapshot               fun(): fml.types.T
---@field public cancel                 fun(): nil

---@param params                        fml.std.scheduler.ISchedulerProps
---@return fml.std.scheduler.IScheduler
function M.debounce(params)
  local fn = params.fn ---@type fun(callback: fml.std.scheduler.IScheduleCallback): fml.types.T
  local callback = params.callback ---@type fml.std.scheduler.IScheduleCallback|nil
  local delay = math.max(1, params.delay or 0) ---@type integer

  local _tick_call = 1 ---@type integer
  local _tick_resolved = 0 ---@type integer
  local _result = nil ---@type fml.types.T

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
            end

            if callback ~= nil then
              callback(ok, result)
            end
          end
        end)
      end
    end, delay)
  end

  ---@return fml.types.T|nil
  local function snapshot()
    return _result
  end

  ---@return nil
  local function cancel()
    _tick_call = _tick_call + 1
  end

  ---@type fml.std.scheduler.IScheduler
  local runner = {
    schedule = schedule,
    snapshot = snapshot,
    cancel = cancel,
  }
  return runner
end

---@param params                        fml.std.scheduler.ISchedulerProps
---@return fml.std.scheduler.IScheduler
function M.throttle(params)
  local fn = params.fn ---@type fun(callback: fml.std.scheduler.IScheduleCallback): fml.types.T
  local callback = params.callback ---@type fml.std.scheduler.IScheduleCallback|nil
  local delay = math.max(1, params.delay or 0) ---@type integer

  local _scheduling = false ---@type boolean

  local _tick_call = 1 ---@type integer
  local _tick_alive = 0 ---@type integer
  local _tick_scheduled = 1 ---@type integer
  local _tick_resolved = 0 ---@type integer
  local _result = nil ---@type fml.types.T

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

  ---@return fml.types.T|nil
  local function snapshot()
    return _result
  end

  ---@return nil
  local function cancel()
    _tick_alive = _tick_call + 1
  end

  ---@type fml.std.scheduler.IScheduler
  local runner = {
    schedule = schedule,
    snapshot = snapshot,
    cancel = cancel,
  }
  return runner
end

return M
