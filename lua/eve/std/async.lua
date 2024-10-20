---@class eve.std.async
local M = {}

---@param name                          string
---@param fn                            fun(): any
---@param callback                      ?fun(ok: boolean, result: any|nil): nil
---@return fun(): nil
function M.run(name, fn, callback)
  local handle
  local cancelled = false

  local function wrapped_fn()
    if cancelled then
      vim.notify('[eve.std.async] run: The "' .. name .. '" was cancelled.')
    else
      local ok, result = pcall(fn)
      if type(callback) == "function" then
        callback(ok, result)
      end
    end
    if handle ~= nil then
      handle:close() -- Close the handle when done
      handle = nil
    end
  end

  ---@diagnostic disable-next-line: undefined-field
  handle = vim.uv.new_async(vim.schedule_wrap(wrapped_fn))
  if handle ~= nil then
    handle:send()
  end

  return function()
    cancelled = true
    if handle ~= nil then
      handle:send() -- Ensure the async function checks the cancelled flag
    end
  end
end

return M
