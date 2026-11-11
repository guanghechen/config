local bootstrap = require("__test__.support.bootstrap")
local support = require("__test__.support.clipboard")
local harness = require("__test__.support.harness")

local t = harness.new()

-- Every case may report errors; the cases that check them record their own.
bootstrap.with_reporter(t)

local nix = require("era.m.clipboard.nix")
local win = require("era.m.clipboard.win")
local wsl = require("era.m.clipboard.wsl")

t:test("nix: uses argv and keeps the output filepath out of the shell script", function()
  local commands = support.capture_commands(t, "")
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
  local commands, options = support.capture_commands(t, "image/png\n")

  t.assert_true(nix.has_image(), "image availability")
  nix.get_image_as_base64()

  t.assert_eq("xclip", commands[1][1], "direct executable")
  t.assert_eq("TARGETS", commands[1][5], "target argument")
  t.assert_eq("xclip", commands[2][1], "image executable")
  t.assert_eq("image/png", commands[2][6], "image target")
  t.assert_false(options[2].text, "binary output")
end)

t:test("win: passes the PowerShell script as one argv entry", function()
  local commands = support.capture_commands(t, "")

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
  local commands = support.capture_commands(t, "")

  wsl.get_image_as_base64()

  local cmd = commands[1]
  t.assert_eq("pwsh.exe", cmd[1], "executable")
  t.assert_eq("-NoProfile", cmd[2], "profile flag")
  t.assert_eq("-Command", cmd[3], "command flag")
  t.assert_true(cmd[4]:find("ToBase64String", 1, true) ~= nil, "PowerShell script")
end)

t:test("nix: base64 encoding preserves binary bytes", function()
  local raw = "a\0b\r\nc"
  support.capture_commands(t, raw)

  local encoded, extra = nix.get_image_as_base64()
  t.assert_eq("YQBiDQpj", encoded, "base64 output")
  t.assert_nil(extra, "extra return value")
end)

t:test("nix: empty image output is reported as failure", function()
  local reports = bootstrap.with_reporter(t)
  support.capture_commands(t, "")

  t.assert_nil(nix.get_image_as_base64(), "base64 output")
  t.assert_eq(1, #reports.error, "error count")
  t.assert_eq("Clipboard image is empty.", reports.error[1].message, "error message")
end)

---A `vim.system` whose processes exit with `code` and print `stderr`.
---@param code                          integer
---@param stderr                        string
---@return fun(): table
local function exiting(code, stderr)
  return function()
    return {
      wait = function()
        return { code = code, signal = 0, stdout = "", stderr = stderr }
      end,
    }
  end
end

-- A failed clipboard process reports an error and the backend returns its failure value. With `paste_filepath`, the
-- case checks every public function of the backend, else only the base64 read.
for _, case in ipairs({
  {
    name = "nix: non-zero image read returns nil",
    backend = nix,
    system = exiting(1, "xclip failed"),
    errors = 1,
    exit_code = 1,
  },
  {
    name = "spawn failure preserves the public return contracts",
    backend = nix,
    system = function()
      error("spawn failed")
    end,
    paste_filepath = "/tmp/image.png",
    errors = 3,
    reported = "spawn failed",
  },
  {
    name = "non-zero exit preserves the public return contracts",
    backend = win,
    system = exiting(127, "missing executable"),
    paste_filepath = [[C:\image.png]],
    errors = 3,
    exit_code = 127,
    stderr = "missing executable",
  },
}) do
  t:test(case.name, function()
    local reports = bootstrap.with_reporter(t)
    t:patch_table(vim, "system", case.system)

    if case.paste_filepath ~= nil then
      t.assert_false(case.backend.has_image(), "image availability")
    end
    t.assert_nil(case.backend.get_image_as_base64(), "base64 output")
    if case.paste_filepath ~= nil then
      t.assert_false(case.backend.paste_image_from_clipboard(case.paste_filepath), "paste result")
    end
    t.assert_eq(case.errors, #reports.error, "error count")
    local details = reports.error[1].details
    if case.exit_code ~= nil then
      t.assert_eq(case.exit_code, details.exit_code, "exit code")
    end
    if case.stderr ~= nil then
      t.assert_eq(case.stderr, details.error, "stderr")
    end
    if case.reported ~= nil then
      t.assert_eq(case.reported, details.error:match(case.reported), "reported error")
    end
  end)
end

t:run()
