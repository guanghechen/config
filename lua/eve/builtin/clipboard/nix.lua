local __module_name__ = "eve.builtin.clipboard.nix" ---@type string

---@class eve.builtin.clipboard.nix
local M = {}

---@return boolean
function M.has_image()
  local cmd = eve.shell.format_command("xclip -selection clipboard -t TARGETS -o") ---@type string
  local output = vim.fn.system(cmd) ---@type string|nil
  return output ~= nil and output:find("image/png") ~= nil
end

---@param filepath                      string
---@return  boolean
function M.paste_image(filepath)
  local cmd = eve.shell.format_command(string.format('xclip -selection clipboard -o -t image/png > "%s"', filepath))
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
  return nil
end

return M
