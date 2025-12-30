local __module_name__ = "stl.shell" ---@type string

---@class stl.shell
---@field public format_command         fun(command?: string): string
local M = {}

if stl.env.IS_MAC or stl.env.IS_NIX or stl.env.IS_WSL then
  ---@param cmd                         ?string|nil
  ---@return string
  function M.format_command(cmd)
    local shell = vim.env.SHELL or vim.o.shell ---@type string
    if cmd == nil or #cmd < 1 then
      return shell
    else
      return "sh -c " .. vim.fn.shellescape(cmd)
    end
  end
elseif stl.env.IS_WIN then
  ---@param cmd                         ?string|nil
  ---@return string
  function M.format_command(cmd)
    local shell = vim.env.SHELL or vim.o.shell ---@type string
    if cmd == nil or #cmd < 1 then
      return shell
    else
      return 'pwsh.exe -NoProfile -Command "' .. cmd:gsub('"', "'") .. '"'
    end
  end
else
  stl.reporter.error({
    from = __module_name__,
    subject = "format_command",
    message = "Bad env",
    details = { env = stl.env },
  })
end

return M
