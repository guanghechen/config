local __module_name__ = "era.m.clipboard.mac" ---@type string

---@class era.m.clipboard.mac
local M = {}

---@param cmd                           string
---@return string
local function format_command(cmd)
  return stl.shell.format_command(cmd) ---@type string
end

---@return string|nil
function M.get_image_as_base64()
  local cmd = format_command("pngpaste - | base64 | tr -d '\\n'") ---@type string
  local output = vim.fn.system(cmd) ---@type string

  local exit_code = vim.v.shell_error
  if exit_code ~= 0 then
    stl.reporter.error({
      from = __module_name__,
      subject = "get_image_as_base64",
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

---@return boolean
function M.has_image()
  local cmd = format_command("pngpaste -") ---@type string
  local output = vim.fn.system(cmd) ---@type string
  local exit_code = vim.v.shell_error ---@type integer
  if exit_code ~= 0 then
    stl.reporter.error({
      from = __module_name__,
      subject = "has_image",
      message = "Failed to run command.",
      details = { cmd = cmd, exit_code = exit_code, output = output },
    })
    return false
  end
  return true
end

---@param filepath                      string
---@return  boolean
function M.paste_image_from_clipboard(filepath)
  local cmd = format_command(string.format('pngpaste - > "%s"', filepath))
  local output = vim.fn.system(cmd) ---@type string|nil
  local exit_code = vim.v.shell_error

  if exit_code ~= 0 then
    stl.reporter.error({
      from = __module_name__,
      subject = "paste_image_from_clipboard",
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

return M
