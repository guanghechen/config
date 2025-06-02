---@class std.job
local M = {}

---@param cmd                           string[]
---@return boolean
---@return string[]
function M.execute_command(cmd)
  local lines = vim.fn.systemlist(cmd)

  if vim.v.shell_error ~= 0 then
    return false, {}
  end

  if #lines > 0 then
    local line = lines[1] ---@type string
    if string.sub(line, 1, 6) == "fatal:" then
      return false, {}
    end
  end

  return true, lines
end

return M
