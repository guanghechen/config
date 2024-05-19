---https://github.com/runiq/neovim-throttle-debounce/blob/5247b097df15016ab31db672b77ec4938bb9cbfd/lua/throttle-debounce/init.lua#L1

---@class guanghechen.util.debounce
local M = {}

--- Debounces a function on the leading edge. Automatically `schedule_wrap()`s.
---`timer:close()` at the end or you will leak memory!
---
---@param fn fun():nil Function to debounce
---@param timeout number Timeout in ms
---@return { debounced: fun():nil, timer:any} Debounced function and timer. Remember to call
function M.debounce_leading(fn, timeout)
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

--- Debounces a function on the trailing edge. Automatically `schedule_wrap()`s.
--- call to `fn` within the timeframe. Default: Use arguments of the last call.
---`timer:close()` at the end or you will leak memory!
---
---@param fn fun():nil Function to debounce
---@param timeout number Timeout in ms
---@param first? boolean Whether to use the arguments of the first
---@return { debounce: fun():nil, timer:any} Debounced function and timer. Remember to call
function M.debounce_trailing(fn, timeout, first)
  local timer = vim.uv.new_timer()
  local debounced

  if not first then
    function debounced(...)
      local argv = { ... }
      local argc = select("#", ...)

      timer:start(timeout, 0, function()
        pcall(vim.schedule_wrap(fn), vim.unpack(argv, 1, argc))
      end)
    end
  else
    local argv, argc
    function debounced(...)
      argv = argv or { ... }
      argc = argc or select("#", ...)

      timer:start(timeout, 0, function()
        pcall(vim.schedule_wrap(fn), vim.unpack(argv, 1, argc))
      end)
    end
  end
  return { debounced = debounced, timer = timer }
end

return M
