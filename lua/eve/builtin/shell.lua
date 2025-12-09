local __module_name__ = "eve.builtin.shell" ---@type string

---@class eve.builtin.shell
---@field public format_command         fun(command?: string): string
local M = {}

if dot.env.IS_MAC or dot.env.IS_NIX or dot.env.IS_WSL then
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
elseif dot.env.IS_WIN then
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
  ark.reporter.error({
    from = __module_name__,
    subject = "format_command",
    message = "Bad env",
    details = { env = dot.env },
  })
end

return M
