---https://github.com/runiq/neovim-throttle-debounce/blob/5247b097df15016ab31db672b77ec4938bb9cbfd/lua/throttle-debounce/init.lua#L1

--- Throttles a function on the leading edge. Automatically `schedule_wrap()`s.
---`timer:close()` at the end or you will leak memory!
---
---@param fn                            fun(): nil  Function to throttle
---@param timeout                       integer     Timeout in ms
---@return { throttled: fun(): nil, timer: any }    Throttled function and timer. Remember to call
local function throttle_leading(fn, timeout)
  local timer = vim.uv.new_timer()
  local running = false

  local function throttled()
    if not running then
      timer:start(timeout, 0, function()
        running = false
      end)
      running = true
      pcall(vim.schedule_wrap(fn))
    end
  end
  return { throttled = throttled, timer = timer }
end

return throttle_leading
