---@class ark.timer.IDisposableCallable
---@field public cancel                 fun(self: ark.timer.IDisposableCallable):nil
---@field public dispose                fun(self: ark.timer.IDisposableCallable):nil
---@field public stop                   fun(self: ark.timer.IDisposableCallable):nil
---@operator call:any

---@class ark.timer
local M = {}

local ffi = require("ffi")

---@alias ark.timer.Guard              ffi.cdata*

local guard_map = setmetatable({}, { __mode = "k" }) ---@type table<uv.uv_timer_t, ark.timer.Guard>

---@param timer                         uv.uv_timer_t
---@return                              ark.timer.Guard
local function create_guard(timer)
  local t = timer ---@type uv.uv_timer_t|nil
  local guard = ffi.gc(ffi.new("uint8_t[1]"), function()
    if t ~= nil and not t:is_closing() then
      t:stop()
      t:close()
    end
    t = nil
  end)
  return guard
end

---@param timer                         uv.uv_timer_t|nil
---@return nil
function M.clear_timer(timer)
  if timer ~= nil and not timer:is_closing() then
    guard_map[timer] = nil
    timer:stop()
    timer:close()
  end
end

---@generic T: function
---@param fn                            T
---@param delay                         integer
---@return ark.timer.IDisposableCallable
function M.debounce(fn, delay)
  local timer = assert(vim.uv.new_timer()) ---@type uv.uv_timer_t
  ---@diagnostic disable-next-line: unused-local
  local guard_ref = create_guard(timer) ---@type ark.timer.Guard|nil
  local wrapped = vim.schedule_wrap(fn)
  local args ---@type table|nil
  local disposed = false ---@type boolean

  local function call(...)
    if disposed then
      return
    end

    args = { ... }
    timer:stop()
    timer:start(delay, 0, function()
      if disposed then
        return
      end

      local call_args = args
      args = nil
      if call_args ~= nil then
        wrapped(unpack(call_args))
      else
        wrapped()
      end
    end)
  end

  local function cancel_pending()
    if disposed then
      return
    end

    timer:stop()
    args = nil
  end

  local function dispose()
    if disposed then
      return
    end

    cancel_pending()
    disposed = true

    ---@diagnostic disable-next-line: unused-local
    guard_ref = nil
    if timer ~= nil and not timer:is_closing() then
      timer:close()
    end
  end

  ---@type ark.timer.IDisposableCallable
  local callable = {
    cancel = cancel_pending,
    stop = cancel_pending,
    dispose = dispose,
  }

  return setmetatable(callable, {
    __call = function(_, ...)
      return call(...)
    end,
  })
end

---@generic T: function
---@param fn                            T
---@param delay                         integer
---@return ark.timer.IDisposableCallable
function M.throttle(fn, delay)
  local timer = assert(vim.uv.new_timer()) ---@type uv.uv_timer_t
  ---@diagnostic disable-next-line: unused-local
  local guard_ref = create_guard(timer) ---@type ark.timer.Guard|nil

  local running = false ---@type boolean
  local trailing_args = nil ---@type table|nil
  local wrapped = vim.schedule_wrap(fn)
  local disposed = false ---@type boolean

  local function execute(call_args)
    if call_args ~= nil then
      wrapped(unpack(call_args))
    else
      wrapped()
    end
  end

  local function on_timer()
    if disposed then
      return
    end

    running = false
    if trailing_args ~= nil then
      local call_args = trailing_args
      trailing_args = nil
      running = true
      timer:start(delay, 0, on_timer)
      execute(call_args)
    end
  end

  local function call(...)
    if disposed then
      return
    end

    if running then
      trailing_args = { ... }
      return
    end

    running = true
    trailing_args = nil
    timer:start(delay, 0, on_timer)
    local call_args = { ... } ---@type table
    execute(call_args)
  end

  local function cancel_pending()
    if disposed then
      return
    end

    timer:stop()
    trailing_args = nil
    running = false
  end

  local function dispose()
    if disposed then
      return
    end

    cancel_pending()
    disposed = true

    ---@diagnostic disable-next-line: unused-local
    guard_ref = nil
    if timer ~= nil and not timer:is_closing() then
      timer:close()
    end
  end

  ---@type ark.timer.IDisposableCallable
  local callable = {
    cancel = cancel_pending,
    stop = cancel_pending,
    dispose = dispose,
  }

  return setmetatable(callable, {
    __call = function(_, ...)
      return call(...)
    end,
  })
end

---@param fn                            function
---@param ms                            integer
---@return uv.uv_timer_t|nil
function M.delay(fn, ms)
  local timer = vim.uv.new_timer()
  if timer ~= nil then
    local guard_ref = create_guard(timer) ---@type ark.timer.Guard|nil
    guard_map[timer] = guard_ref
    timer:start(
      ms,
      0,
      vim.schedule_wrap(function()
        guard_map[timer] = nil
        guard_ref = nil ---@diagnostic disable-line: cast-local-type
        if not timer:is_closing() then
          timer:close()
        end

        fn()
      end)
    )
  end
  return timer
end

---@param fn                            function
---@param interval                      integer
---@return uv.uv_timer_t|nil
function M.set_interval(fn, interval)
  local timer = vim.uv.new_timer()
  if timer ~= nil then
    local guard_ref = create_guard(timer) ---@type ark.timer.Guard|nil
    guard_map[timer] = guard_ref
    timer:start(
      interval,
      interval,
      vim.schedule_wrap(function()
        if timer:is_closing() then
          guard_map[timer] = nil
          guard_ref = nil ---@diagnostic disable-line: cast-local-type
          return
        end

        fn()

        if timer:is_closing() then
          guard_map[timer] = nil
          guard_ref = nil ---@diagnostic disable-line: cast-local-type
        end
      end)
    )
  end
  return timer
end

return M
