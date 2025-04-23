---@class eve.std.timer
local M = {}

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

---@param timer                         uv.uv_timer_t|nil
---@return nil
function M.clear_timer(timer)
  if timer ~= nil and not timer:is_closing() then
    timer:close()
  end
end

return M
