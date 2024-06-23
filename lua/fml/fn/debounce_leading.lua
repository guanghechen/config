---https://github.com/runiq/neovim-throttle-debounce/blob/5247b097df15016ab31db672b77ec4938bb9cbfd/lua/throttle-debounce/init.lua#L1

--- Debounces a function on the leading edge. Automatically `schedule_wrap()`s.
---`timer:close()` at the end or you will leak memory!
---
---@param fn                            fun(): nil  Function to debounce
---@param timeout                       number      Timeout in ms
---@return { debounced: fun(): nil, timer: any}     Debounced function and timer. Remember to call
local function debounce_leading(fn, timeout)
  local timer = vim.uv.new_timer()
  local running = false

  local function debounced(...)
    timer:start(timeout, 0, function()
      running = false
    end)

    if not running then
      running = true
      pcall(vim.schedule_wrap(fn), select(1, ...))
    end
  end

  return { debounced = debounced, timer = timer }
end

return debounce_leading
