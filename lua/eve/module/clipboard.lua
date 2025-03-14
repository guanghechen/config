local __module_name__ = "eve.module.clipboard" ---@type string

local tmux = require("eve.std.tmux")

---@class fml.lib.clipboard
local M = {}

if eve.env.IS_MAC then
  if eve.env.IS_TMUX then
    function M.get_clipboard()
      local fake_clipboard_filepath = tmux.get_tmux_env_value("ghc_use_fake_clipboard")
      if fake_clipboard_filepath == nil or not eve.std.path.is_exist(fake_clipboard_filepath) then
        return
      end

      eve.std.reporter.info({
        from = __module_name__,
        message = "Using fake clipboard:" .. fake_clipboard_filepath,
      })

      local clipboard_file = vim.fn.expand(fake_clipboard_filepath)

      ---@return string
      local function read_from_fake_clipboard()
        local file = io.open(clipboard_file, "r")
        if file == nil then
          eve.std.reporter.error({
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
          eve.std.reporter.error({
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
elseif eve.env.IS_WSL then
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
  function M.get_clipboard()
    return nil
  end
end

return M
