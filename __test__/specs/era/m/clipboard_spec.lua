--- Run with: nvim -l __test__/run.lua __test__/specs/era/m/clipboard_spec.lua
---@diagnostic disable: undefined-global
--- Test for era.m.clipboard process commands

local bootstrap = require("__test__.support.bootstrap")
local harness = require("__test__.support.harness")

local t = harness.new("era.m.clipboard")
local reports = {} ---@type table[]

bootstrap.with_runtime(t, {
  stl = {
    reporter = {
      error = function(report)
        reports[#reports + 1] = report
      end,
    },
  },
})

local nix = require("era.m.clipboard.nix")
local win = require("era.m.clipboard.win")
local wsl = require("era.m.clipboard.wsl")

---@param output                        string
---@return string[][]
---@return vim.SystemOpts[]
local function capture_commands(output)
  local commands = {} ---@type string[][]
  local options = {} ---@type vim.SystemOpts[]
  t:patch_table(vim, "system", function(cmd, opts)
    commands[#commands + 1] = cmd
    options[#options + 1] = opts
    return {
      wait = function()
        return { code = 0, signal = 0, stdout = output, stderr = "" }
      end,
    }
  end)
  return commands, options
end

t:test("nix: uses argv and keeps the output filepath out of the shell script", function()
  local commands = capture_commands("")
  local filepath = "/tmp/$(touch nope) O'Brien.png"

  t.assert_true(nix.paste_image_from_clipboard(filepath), "paste result")

  local cmd = commands[1]
  t.assert_eq("sh", cmd[1], "shell executable")
  t.assert_eq("-c", cmd[2], "shell flag")
  t.assert_eq('xclip -selection clipboard -o -t image/png > "$1"', cmd[3], "shell script")
  t.assert_eq("sh", cmd[4], "command name")
  t.assert_eq(filepath, cmd[5], "filepath argument")
end)

t:test("nix: runs clipboard reads directly as argv", function()
  local commands, options = capture_commands("image/png\n")

  t.assert_true(nix.has_image(), "image availability")
  nix.get_image_as_base64()

  t.assert_eq("xclip", commands[1][1], "direct executable")
  t.assert_eq("TARGETS", commands[1][5], "target argument")
  t.assert_eq("xclip", commands[2][1], "image executable")
  t.assert_eq("image/png", commands[2][6], "image target")
  t.assert_false(options[2].text, "binary output")
end)

t:test("win: passes the PowerShell script as one argv entry", function()
  local commands = capture_commands("")

  t.assert_true(win.paste_image_from_clipboard([[C:\Users\O'Brien\image.png]]), "paste result")

  local cmd = commands[1]
  t.assert_eq("pwsh.exe", cmd[1], "executable")
  t.assert_eq("-NoProfile", cmd[2], "profile flag")
  t.assert_eq("-Command", cmd[3], "command flag")
  t.assert_eq(
    [[Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.Clipboard]::GetImage().Save('C:\Users\O''Brien\image.png')]],
    cmd[4],
    "escaped script"
  )
end)

t:test("wsl: passes the PowerShell script as one argv entry", function()
  local commands = capture_commands("")

  wsl.get_image_as_base64()

  local cmd = commands[1]
  t.assert_eq("pwsh.exe", cmd[1], "executable")
  t.assert_eq("-NoProfile", cmd[2], "profile flag")
  t.assert_eq("-Command", cmd[3], "command flag")
  t.assert_true(cmd[4]:find("ToBase64String", 1, true) ~= nil, "PowerShell script")
end)

t:test("nix: base64 encoding preserves binary bytes", function()
  local raw = "a\0b\r\nc"
  capture_commands(raw)

  local encoded, extra = nix.get_image_as_base64()
  t.assert_eq("YQBiDQpj", encoded, "base64 output")
  t.assert_nil(extra, "extra return value")
end)

t:test("nix: empty image output is reported as failure", function()
  reports = {}
  capture_commands("")

  t.assert_nil(nix.get_image_as_base64(), "base64 output")
  t.assert_eq(1, #reports, "error count")
  t.assert_eq("Clipboard image is empty.", reports[1].message, "error message")
end)

t:test("nix: non-zero image read returns nil", function()
  reports = {}
  t:patch_table(vim, "system", function()
    return {
      wait = function()
        return { code = 1, signal = 0, stdout = "", stderr = "xclip failed" }
      end,
    }
  end)

  t.assert_nil(nix.get_image_as_base64(), "base64 output")
  t.assert_eq(1, #reports, "error count")
  t.assert_eq(1, reports[1].details.exit_code, "exit code")
end)

t:test("spawn failure preserves the public return contracts", function()
  reports = {}
  t:patch_table(vim, "system", function()
    error("spawn failed")
  end)

  t.assert_false(nix.has_image(), "image availability")
  t.assert_nil(nix.get_image_as_base64(), "base64 output")
  t.assert_false(nix.paste_image_from_clipboard("/tmp/image.png"), "paste result")
  t.assert_eq(3, #reports, "error count")
  t.assert_eq("spawn failed", reports[1].details.error:match("spawn failed"), "reported error")
end)

t:test("non-zero exit preserves the public return contracts", function()
  reports = {}
  t:patch_table(vim, "system", function()
    return {
      wait = function()
        return { code = 127, signal = 0, stdout = "", stderr = "missing executable" }
      end,
    }
  end)

  t.assert_false(win.has_image(), "image availability")
  t.assert_nil(win.get_image_as_base64(), "base64 output")
  t.assert_false(win.paste_image_from_clipboard([[C:\image.png]]), "paste result")
  t.assert_eq(3, #reports, "error count")
  t.assert_eq(127, reports[1].details.exit_code, "exit code")
  t.assert_eq("missing executable", reports[1].details.error, "stderr")
end)

t:run()
