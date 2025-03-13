local __module_name__ = "eve.module.clipboard" ---@type string

local env = require("eve.std.env")
local reporter = require("eve.builtin.reporter")
local shell = require("eve.builtin.shell")

---@class eve.module.clipboard.img
---@field public has_image              fun(): boolean
---@field public paste_image            fun(filepath: string): boolean
local M = {}

if env.IS_MAC then
  ---@return boolean
  function M.has_image()
    local cmd = shell.format_command("pngpaste -") ---@type string
    local output = vim.fn.system(cmd) ---@type string|nil
    local exit_code = vim.v.shell_error

    if exit_code ~= 0 and #output > 0 then
      reporter.error({
        from = __module_name__,
        subject = "check_have_img",
        message = "Failed to run command.",
        details = { cmd = cmd, exit_code = exit_code, output = output, shell_error = vim.v.shell_error },
      })
    end
    return exit_code == 0
  end

  ---@param filepath                    string
  ---@return  boolean
  function M.paste_image(filepath)
    local cmd = shell.format_command(string.format('pngpaste - > "%s"', filepath))
    local output = vim.fn.system(cmd) ---@type string|nil
    local exit_code = vim.v.shell_error

    if exit_code ~= 0 and #output > 0 then
      reporter.error({
        from = __module_name__,
        subject = "check_have_img",
        message = "Failed to run command.",
        details = { cmd = cmd, exit_code = exit_code, output = output, shell_error = vim.v.shell_error },
      })
    end
    return exit_code == 0
  end
elseif env.IS_NIX then
  ---@return boolean
  function M.has_image()
    local cmd = shell.format_command("xclip -selection clipboard -t TARGETS -o") ---@type string
    local output = vim.fn.system(cmd) ---@type string|nil
    return output ~= nil and output:find("image/png") ~= nil
  end

  ---@param filepath                    string
  ---@return  boolean
  function M.paste_image(filepath)
    local cmd = shell.format_command(string.format('xclip -selection clipboard -o -t image/png > "%s"', filepath))
    local output = vim.fn.system(cmd) ---@type string|nil
    local exit_code = vim.v.shell_error

    if exit_code ~= 0 and #output > 0 then
      reporter.error({
        from = __module_name__,
        subject = "check_have_img",
        message = "Failed to run command.",
        details = { cmd = cmd, exit_code = exit_code, output = output, shell_error = vim.v.shell_error },
      })
    end
    return exit_code == 0
  end
elseif env.IS_WIN or env.IS_WSL then
  ---@param cmd                         string
  ---@return string
  local function format_command(cmd)
    return 'pwsh.exe -NoProfile -Command "' .. cmd:gsub('"', "'") .. '"'
  end

  ---@return boolean
  function M.has_image()
    local cmd =
      format_command("Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.Clipboard]::GetImage()")
    local output = vim.fn.system(cmd) ---@type string|nil
    return output ~= nil and output:find("Width") ~= nil
  end

  ---@param filepath                    string
  ---@return  boolean
  function M.paste_image(filepath)
    local cmd = format_command(
      string.format(
        "Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.Clipboard]::GetImage().Save('%s')",
        filepath
      )
    )
    local output = vim.fn.system(cmd) ---@type string|nil
    local exit_code = vim.v.shell_error

    if exit_code ~= 0 and #output > 0 then
      reporter.error({
        from = __module_name__,
        subject = "check_have_img",
        message = "Failed to run command.",
        details = { cmd = cmd, exit_code = exit_code, output = output, shell_error = vim.v.shell_error },
      })
    end
    return exit_code == 0
  end
end

return M
