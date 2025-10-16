---@class std.timer
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
  local wrapped = vim.schedule_wrap(fn) ---@type T
  local unpack = table.unpack or unpack ---@type fun(list: table, i?: integer, j?: integer): ...
  local args ---@type table|nil

  local function call(...)
    args = { ... }
    timer:stop()
    timer:start(delay, 0, function()
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

  return call
end

---@generic T
---@param fn                            T
---@param delay                         integer
---@return T
function M.throttle(fn, delay)
  local timer = assert(vim.uv.new_timer()) ---@type uv.uv_timer_t
  local pending = false ---@type boolean
  local wrapped = vim.schedule_wrap(fn) ---@type T
  local unpack = table.unpack or unpack ---@type fun(list: table, i?: integer, j?: integer): ...
  local args ---@type table|nil
  return function(...)
    if pending then
      return
    end

    pending = true
    args = { ... }
    timer:start(delay, 0, function()
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
