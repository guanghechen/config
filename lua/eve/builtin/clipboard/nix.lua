local __module_name__ = "eve.builtin.clipboard.nix" ---@type string

---@class eve.builtin.clipboard.nix
local M = {}

---@param cmd                           string
---@return string
local function format_command(cmd)
  return eve.shell.format_command(cmd) ---@type string
end

---@return boolean
function M.has_image()
  local cmd = format_command("xclip -selection clipboard -t TARGETS -o") ---@type string
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
  end

  return output:find("image/png") ~= nil
end

---@return string|nil
function M.get_image_as_base64()
  local cmd = format_command("xclip -selection clipboard -o -t image/png | base64 | tr -d '\n'") ---@type string
  local output = vim.fn.system(cmd) ---@type string

  local exit_code = vim.v.shell_error
  if exit_code ~= 0 then
    eve.reporter.error({
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

---@param filepath                      string
---@return  boolean
function M.paste_image(filepath)
  local cmd = format_command(string.format('xclip -selection clipboard -o -t image/png > "%s"', filepath))
  local output = vim.fn.system(cmd) ---@type string|nil
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

function M.get_clipboard()
  return nil
end

return M
