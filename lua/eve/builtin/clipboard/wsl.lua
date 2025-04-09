local __module_name__ = "eve.builtin.clipboard.wsl" ---@type string

---@class eve.builtin.clipboard.wsl
local M = {}

---@param cmd                           string
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

---@param filepath                      string
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
    eve.reporter.error({
      from = __module_name__,
      subject = "check_have_img",
      message = "Failed to run command.",
      details = { cmd = cmd, exit_code = exit_code, output = output, shell_error = vim.v.shell_error },
    })
  end
  return exit_code == 0
end

function M.get_clipboard()
  return {
    name = "WslClipboard",
    copy = {
      ["+"] = "clip.exe",
      ["*"] = "clip.exe",
    },
    paste = {
      ["+"] = 'pwsh.exe -c [Console]::Out.Write($(Get-Clipboard -Raw).tostring().replace("`r", ""))',
      ["*"] = 'pwsh.exe -c [Console]::Out.Write($(Get-Clipboard -Raw).tostring().replace("`r", ""))',
    },
    cache_enabled = 0,
  }
end

return M
