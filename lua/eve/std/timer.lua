---@class eve.std.timer
local M = {}

---@param timer                         uv.uv_timer_t|nil
---@return nil
function M.clear_timer(timer)
  if timer ~= nil and not timer:is_closing() then
    timer:close()
  end
end

---@generic T
---@param fn                            T
---@param delay                         integer
---@return T
function M.debounce(fn, delay)
  local timer = assert(vim.uv.new_timer()) ---@type uv.uv_timer_t
  return function()
    timer:stop()
    timer:start(delay, 0, vim.schedule_wrap(fn))
  end
end

---@generic T
---@param fn                            T
---@param delay                         integer
---@return T
function M.throttle(fn, delay)
  local timer = assert(vim.uv.new_timer()) ---@type uv.uv_timer_t
  local pending = false ---@type boolean
  return function()
    if pending then
      return
    end

    pending = true
    timer:start(delay, 0, function()
      pending = false
      vim.schedule(fn)
    end)
  end
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
