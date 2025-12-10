---@class std.timer.IDisposableCallable
---@field public cancel                 fun(self: std.timer.IDisposableCallable):nil
---@field public dispose                fun(self: std.timer.IDisposableCallable):nil
---@field public stop                   fun(self: std.timer.IDisposableCallable):nil
---@operator call:any

---@class std.timer
local M = {}

---@param timer                         uv.uv_timer_t|nil
---@return nil
function M.clear_timer(timer)
  if timer ~= nil and not timer:is_closing() then
    timer:close()
  end
end

---@generic T: function
---@param fn                            T
---@param delay                         integer
---@return std.timer.IDisposableCallable
function M.debounce(fn, delay)
  local timer = assert(vim.uv.new_timer()) ---@type uv.uv_timer_t
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

      timer:stop()
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
    if timer ~= nil and not timer:is_closing() then
      timer:close()
    end
  end

  ---@type std.timer.IDisposableCallable
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
---@return std.timer.IDisposableCallable
function M.throttle(fn, delay)
  local timer = assert(vim.uv.new_timer()) ---@type uv.uv_timer_t
  local pending = false ---@type boolean
  local wrapped = vim.schedule_wrap(fn)
  local args ---@type table|nil
  local disposed = false ---@type boolean

  local function call(...)
    if pending or disposed then
      return
    end

    pending = true
    args = { ... }
    timer:start(delay, 0, function()
      if disposed then
        return
      end

      pending = false
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
    pending = false
  end

  local function dispose()
    if disposed then
      return
    end

    cancel_pending()
    disposed = true
    if timer ~= nil and not timer:is_closing() then
      timer:close()
    end
  end

  ---@type std.timer.IDisposableCallable
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
---@param timeout                       integer
---@return uv.uv_timer_t|nil
function M.set_timeout(fn, timeout)
  local timer = vim.uv.new_timer()
  if timer ~= nil then
    timer:start(
      timeout,
      0,
      vim.schedule_wrap(function()
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
    timer:start(
      interval,
      interval,
      vim.schedule_wrap(function()
        if not timer:is_closing() then
          fn()
        end
      end)
    )
  end
  return timer
end

return M
