---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.clipboard.wsl" ---@type string

---@class era.m.clipboard.wsl
local M = {}

local exec = require("era.m.clipboard.exec")

---@param script                        string
---@return string[]
local function powershell_command(script)
  return { "pwsh.exe", "-NoProfile", "-Command", script }
end

---@return boolean
function M.has_image()
  local cmd =
    powershell_command("Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.Clipboard]::GetImage()")
  local result = exec.run(__module_name__, "has_image", cmd)
  if result == nil then
    return false
  end

  return (result.stdout or ""):find("Width") ~= nil
end

---@return string|nil
function M.get_image_as_base64()
  local cmd = powershell_command(
    [[Add-Type -AssemblyName System.Windows.Forms; $ms = New-Object System.IO.MemoryStream;]]
      .. [[ [System.Windows.Forms.Clipboard]::GetImage().Save($ms, [System.Drawing.Imaging.ImageFormat]::Png);]]
      .. [[ [System.Convert]::ToBase64String($ms.ToArray())]]
  )
  local result = exec.run(__module_name__, "get_image_as_base64", cmd)
  if result == nil then
    return nil
  end

  local encoded = (result.stdout or ""):gsub("\r\n", ""):gsub("\n", ""):gsub("\r", "")
  return encoded
end

---@param filepath                      string
---@return  boolean
function M.paste_image_from_clipboard(filepath)
  local escaped_filepath = filepath:gsub("'", "''")
  local cmd = powershell_command(
    string.format(
      "Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.Clipboard]::GetImage().Save('%s')",
      escaped_filepath
    )
  )
  return exec.run(__module_name__, "paste_image_from_clipboard", cmd, nil, { filepath = filepath }) ~= nil
end

return M
