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
  local output = vim.fn.system(cmd) ---@type string

  local exit_code = vim.v.shell_error
  if exit_code ~= 0 then
    eve.reporter.error({
      from = __module_name__,
      subject = "has_image",
      message = "Failed to run command.",
      details = {
        cmd = cmd,
        exit_code = exit_code,
        output = output,
        shell_error = vim.v.shell_error,
      },
    })
    return false
  end

  return output:find("Width") ~= nil
end

---@return string|nil
function M.get_image_base64()
  local cmd = format_command(
    [[Add-Type -AssemblyName System.Windows.Forms; $ms = New-Object System.IO.MemoryStream;]]
      .. [[ [System.Windows.Forms.Clipboard]::GetImage().Save($ms, [System.Drawing.Imaging.ImageFormat]::Png);]]
      .. [[ [System.Convert]::ToBase64String($ms.ToArray())]]
  )
  local output = vim.fn.system(cmd) ---@type string

  local exit_code = vim.v.shell_error
  if exit_code ~= 0 then
    eve.reporter.error({
      from = __module_name__,
      subject = "get_image_base64",
      message = "Failed to run command.",
      details = {
        cmd = cmd,
        exit_code = exit_code,
        output = output,
        shell_error = vim.v.shell_error,
      },
    })
    return nil
  end

  local result = output:gsub("\r\n", ""):gsub("\n", ""):gsub("\r", "")
  return result
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
  local output = vim.fn.system(cmd) ---@type string

  local exit_code = vim.v.shell_error
  if exit_code ~= 0 then
    eve.reporter.error({
      from = __module_name__,
      subject = "paste_image",
      message = "Failed to run command.",
      details = {
        cmd = cmd,
        exit_code = exit_code,
        filepath = filepath,
        output = output,
        shell_error = vim.v.shell_error,
      },
    })
    return false
  end

  return true
end

---@param filepath                      string
---@return string|nil
function M.read_as_base64(filepath)
  local cmd =
    format_command(string.format("[System.Convert]::ToBase64String([System.IO.File]::ReadAllBytes('%s'))", filepath))
  local output = vim.fn.system(cmd) ---@type string

  local exit_code = vim.v.shell_error
  if exit_code ~= 0 then
    eve.reporter.error({
      from = __module_name__,
      subject = "read_as_base64",
      message = "Failed to run command.",
      details = {
        cmd = cmd,
        exit_code = exit_code,
        filepath = filepath,
        output = output,
        shell_error = vim.v.shell_error,
      },
    })
    return nil
  end

  local result = output:gsub("\r\n", ""):gsub("\n", ""):gsub("\r", "") ---@type string
  return result
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
