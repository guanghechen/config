local __module_name__ = "eve.builtin.clipboard.mac" ---@type string

---@class eve.builtin.clipboard.mac
local M = {}

---@param cmd                           string
---@return string
local function format_command(cmd)
  return eve.shell.format_command(cmd) ---@type string
end

---@return string|nil
function M.get_image_as_base64()
  local cmd = format_command("pngpaste - | base64 | tr -d '\n'") ---@type string
  local output = vim.fn.system(cmd) ---@type string

  local exit_code = vim.v.shell_error
  if exit_code ~= 0 then
    std.reporter.error({
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

  local exit_code = vim.v.shell_error
  if exit_code ~= 0 then
    std.reporter.error({
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

  return true
end

---@param filepath                      string
---@return  boolean
function M.paste_image_from_clipboard(filepath)
  local cmd = format_command(string.format('pngpaste - > "%s"', filepath))
  local output = vim.fn.system(cmd) ---@type string|nil
  local exit_code = vim.v.shell_error

  if exit_code ~= 0 then
    std.reporter.error({
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

if std.env.IS_TMUX then
  function M.get_clipboard()
    local fake_clipboard_filepath = eve.tmux.get_tmux_env_value("ghc_use_fake_clipboard")
    if fake_clipboard_filepath == nil or not std.path.is_exist(fake_clipboard_filepath) then
      return
    end

    std.reporter.info({
      from = __module_name__,
      message = "Using fake clipboard:" .. fake_clipboard_filepath,
    })

    local clipboard_file = vim.fn.expand(fake_clipboard_filepath)

    ---@return string
    local function read_from_fake_clipboard()
      local file = io.open(clipboard_file, "r")
      if file == nil then
        std.reporter.error({
          from = __module_name__,
          subject = "read_from_fake_clipboard",
          message = "Unable to open fake clipboard file for reading.",
          details = {
            filepath = fake_clipboard_filepath,
          },
        })
        return ""
      end

      local content = file:read("*a")
      file:close()
      return content
    end

    ---@param data                      string|string[]
    ---@return nil
    local function write_to_fake_clipboard(data)
      local file = io.open(clipboard_file, "w")
      if file == nil then
        std.reporter.error({
          from = __module_name__,
          subject = "write_to_fake_clipboard",
          message = "Unable to open fake clipboard file for writing.",
          details = {
            filepath = fake_clipboard_filepath,
          },
        })
        return
      end

      local content = "" ---@type string
      if type(data) == "string" then
        content = data
      elseif type(data) == "table" then
        content = table.concat(data, "\n")
      end

      file:write(content)
      file:close()
    end

    return {
      name = "MacOsFakeClipboard",
      copy = {
        ["+"] = write_to_fake_clipboard,
        ["*"] = write_to_fake_clipboard,
      },
      paste = {
        ["+"] = read_from_fake_clipboard,
        ["*"] = read_from_fake_clipboard,
      },
      cache_enabled = 0,
    }
  end
else
  function M.get_clipboard()
    return nil
  end
end

return M
