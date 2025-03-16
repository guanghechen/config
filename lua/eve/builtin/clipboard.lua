local __module_name__ = "eve.builtin.clipboard" ---@type string

---@class eve.builtin.clipboard
---@field public has_image              fun(): boolean
---@field public paste_image            fun(filepath: string): boolean
---@field public get_clipboard          fun(): table|nil
local M = {}

if eve.env.IS_MAC then
  ---@return boolean
  function M.has_image()
    local cmd = eve.shell.format_command("pngpaste -") ---@type string
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

  ---@param filepath                    string
  ---@return  boolean
  function M.paste_image(filepath)
    local cmd = eve.shell.format_command(string.format('pngpaste - > "%s"', filepath))
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

  if eve.env.IS_TMUX then
    function M.get_clipboard()
      local fake_clipboard_filepath = eve.tmux.get_tmux_env_value("ghc_use_fake_clipboard")
      if fake_clipboard_filepath == nil or not eve.path.is_exist(fake_clipboard_filepath) then
        return
      end

      eve.reporter.info({
        from = __module_name__,
        message = "Using fake clipboard:" .. fake_clipboard_filepath,
      })

      local clipboard_file = vim.fn.expand(fake_clipboard_filepath)

      ---@return string
      local function read_from_fake_clipboard()
        local file = io.open(clipboard_file, "r")
        if file == nil then
          eve.reporter.error({
            from = __module_name__,
            subject = "macos_fake_clipborad",
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

      ---@param data                    string|string[]
      ---@return nil
      local function write_to_fake_clipboard(data)
        local file = io.open(clipboard_file, "w")
        if file == nil then
          eve.reporter.error({
            from = __module_name__,
            subject = "macos_fake_clipborad",
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
elseif eve.env.IS_NIX then
  ---@return boolean
  function M.has_image()
    local cmd = eve.shell.format_command("xclip -selection clipboard -t TARGETS -o") ---@type string
    local output = vim.fn.system(cmd) ---@type string|nil
    return output ~= nil and output:find("image/png") ~= nil
  end

  ---@param filepath                    string
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
elseif eve.env.IS_WSL then
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
else
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
end

return M
