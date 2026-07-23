---@diagnostic disable-next-line: unused-local
local __module_name__ = "stl.shell" ---@type string

---@class stl.shell
---@field public get_shell_args         fun(command: string): string[]
local M = {}

if stl.env.IS_MAC or stl.env.IS_NIX or stl.env.IS_WSL then
  ---@param cmd                         string
  ---@return string[]
  function M.get_shell_args(cmd)
    return { "sh", "-c", cmd }
  end
elseif stl.env.IS_WIN then
  ---@param cmd                         string
  ---@return string[]
  function M.get_shell_args(cmd)
    return { "pwsh.exe", "-NoProfile", "-Command", cmd }
  end
else
  stl.reporter.error({
    from = __module_name__,
    subject = "get_shell_args",
    message = "Bad env",
    details = { env = stl.env },
  })
end

return M
