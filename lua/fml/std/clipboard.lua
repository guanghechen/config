local std_os = require("fc.std.os")
local path = require("fml.std.path")
local tmux = require("fc.std.tmux")
local reporter = require("fml.std.reporter")

---@class fml.std.clipboard
local M = {}

local function wsl_clipboard()
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

---@param fake_clipboard_filepath string
local function macos_fake_clipborad(fake_clipboard_filepath)
  local clipboard_file = vim.fn.expand(fake_clipboard_filepath)

  ---@param data string|string[]
  local function write_to_fake_clipboard(data)
    local file = io.open(clipboard_file, "w")
    if file == nil then
      reporter.error({
        from = "fml.std.clipboard",
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

  ---@return string
  local function read_from_fake_clipboard()
    local file = io.open(clipboard_file, "r")
    if file == nil then
      reporter.error({
        from = "fml.std.clipboard",
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

  return {
    name = "MacosFakeClipboard",
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

function M.get_clipboard()
  if std_os.is_wsl() then
    return wsl_clipboard()
  end
  if std_os.is_mac() then
    if vim.env.TMUX ~= nil then
      local fake_clipboard_filepath = tmux.get_tmux_env_value("ghc_use_fake_clipboard")
      if fake_clipboard_filepath ~= nil and path.is_exist(fake_clipboard_filepath) then
        reporter.info({
          from = "fml.std.clipboard",
          subject = "get_clipboard",
          message = "Using fake clipboard:" .. fake_clipboard_filepath,
        })
        return macos_fake_clipborad(fake_clipboard_filepath)
      end
      return nil
    end
  end
  return nil
end

return M
