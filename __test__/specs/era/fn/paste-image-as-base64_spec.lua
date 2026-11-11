local bootstrap = require("__test__.support.bootstrap")
local support = require("__test__.support.clipboard")
local harness = require("__test__.support.harness")

local t = harness.new()

-- Every case may report errors; the cases that check them record their own.
bootstrap.with_reporter(t)

local osx = require("era.m.clipboard.osx")
local win = require("era.m.clipboard.win")
local wsl = require("era.m.clipboard.wsl")
local paste_image_as_base64 = require("era.fn.paste-image-as-base64")

t:test("base64 paste reads and encodes the macOS clipboard in one process", function()
  local commands = support.capture_commands(t, "YWJj\r\n")
  t:patch_global("era", { m = { clipboard = osx } })

  t.assert_eq("YWJj", paste_image_as_base64(), "base64 image")
  t.assert_eq(1, #commands, "clipboard process count")
  t.assert_eq("pngpaste", commands[1][1], "clipboard executable")
  t.assert_eq("-b", commands[1][2], "base64 mode")
end)

t:test("base64 paste treats empty successful output as no image", function()
  for _, clipboard in ipairs({ osx, win, wsl }) do
    local commands = support.capture_commands(t, "\r\n")
    t:patch_global("era", { m = { clipboard = clipboard } })

    t.assert_nil(paste_image_as_base64(), "no image")
    t.assert_eq(1, #commands, "clipboard process count")
  end
end)

t:test("base64 paste reports a failed clipboard read once and returns nil", function()
  local reports = bootstrap.with_reporter(t)
  local calls = 0 ---@type integer
  t:patch_global("era", { m = { clipboard = osx } })
  t:patch_table(vim, "system", function()
    calls = calls + 1
    return {
      wait = function()
        return { code = 1, signal = 0, stdout = "", stderr = "no image" }
      end,
    }
  end)

  t.assert_nil(paste_image_as_base64(), "failed read")
  t.assert_eq(1, calls, "clipboard process count")
  t.assert_eq(1, #reports.error, "error count")
end)

t:run()
