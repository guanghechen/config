---@class fml.std.async
local M = {}

---@alias fml.std.async.IRunCallback
---| fun(ok: boolean, result: fml.types.T|nil): nil

---@class fml.std.async.IRunnerProps
---@field public fn                    fun(callback: fml.std.async.IRunCallback): fml.types.T
---@field public callback              ?fml.std.async.IRunCallback
---@field public delay                 ?integer

---@class fml.std.async.IRunner
---@field public run                    fun(): nil
---@field public snapshot               fun(): fml.types.T
---@field public cancel                 fun(): nil

---@param params                        fml.std.async.IRunnerProps
---@return fml.std.async.IRunner
function M.debounce(params)
  local fn = params.fn ---@type fun(callback: fml.std.async.IRunCallback): fml.types.T
  local callback = params.callback ---@type fml.std.async.IRunCallback|nil
  local delay = math.max(1, params.delay or 0) ---@type integer

  local _call_tick = 1 ---@type integer
  local _resolved_tick = 0 ---@type integer
  local _valid_tick = 0 ---@type integer
  local _result = nil ---@type fml.types.T

  ---@return nil
  local function run()
    _call_tick = _call_tick + 1
    _valid_tick = _call_tick

    local tick_snapshot = _call_tick ---@type integer
    vim.defer_fn(function()
      if tick_snapshot < _valid_tick then
        return
      end

      fn(function(ok, result)
        if _resolved_tick < tick_snapshot then
          if ok then
            _result = result
            _resolved_tick = tick_snapshot
          end

          if callback ~= nil then
            callback(ok, result)
          end
        end
      end)
    end, delay)
  end

  ---@return fml.types.T|nil
  local function snapshot()
    return _result
  end

  ---@return nil
  local function cancel()
    _valid_tick = _call_tick + 1
  end

  ---@type fml.std.async.IRunner
  local runner = {
    run = run,
    snapshot = snapshot,
    cancel = cancel,
  }
  return runner
end

---@param params                        fml.std.async.IRunnerProps
---@return fml.std.async.IRunner
function M.throttle(params)
  local fn = params.fn ---@type fun(callback: fml.std.async.IRunCallback): fml.types.T
  local callback = params.callback ---@type fml.std.async.IRunCallback|nil
  local delay = math.max(1, params.delay or 0) ---@type integer

  local _running = false ---@type boolean
  local _call_tick = 1 ---@type integer
  local _resolved_tick = 0 ---@type integer
  local _valid_tick = 0 ---@type integer
  local _result = nil ---@type fml.types.T

  ---@return nil
  local function run()
    _call_tick = _call_tick + 1

    if _running then
      return
    end

    _running = true

    _valid_tick = _call_tick
    local tick_snapshot = _valid_tick ---@type integer
    vim.defer_fn(function()
      if tick_snapshot < _valid_tick then
        _running = false
        return
      end

      fn(function(ok, result)
        if _resolved_tick < tick_snapshot then
          if ok then
            _result = result
            _resolved_tick = tick_snapshot
          end

          if callback ~= nil then
            callback(ok, result)
          end
        end

        _running = false
        if _valid_tick < _call_tick then
          run()
        end
      end)
    end, delay)
  end

  ---@return fml.types.T|nil
  local function snapshot()
    return _result
  end

  ---@return nil
  local function cancel()
    _valid_tick = _call_tick + 1
  end

  ---@type fml.std.async.IRunner
  local runner = {
    run = run,
    snapshot = snapshot,
    cancel = cancel,
  }
  return runner
end

return M
