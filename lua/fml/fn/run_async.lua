---@param fn                            fun(): nil
---@return nil
local function run_async(fn)
  local async_handle
  async_handle = vim.uv.new_async(vim.schedule_wrap(function()
    fn()
    async_handle:close() -- Close the handle when done
  end))
  async_handle:send()
end

return run_async
