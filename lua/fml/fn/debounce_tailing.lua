---https://github.com/runiq/neovim-throttle-debounce/blob/5247b097df15016ab31db672b77ec4938bb9cbfd/lua/throttle-debounce/init.lua#L1

--- Debounces a function on the trailing edge. Automatically `schedule_wrap()`s.
--- call to `fn` within the timeframe. Default: Use arguments of the last call.
---`timer:close()` at the end or you will leak memory!
---
---@param fn                            fun(): nil  Function to debounce
---@param timeout                       number      Timeout in ms
---@param first                         ?boolean    Whether to use the arguments of the first
---@return { debounce: fun(): nil, timer: any}      Debounced function and timer. Remember to call
local function debounce_tailing(fn, timeout, first)
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

return debounce_tailing
