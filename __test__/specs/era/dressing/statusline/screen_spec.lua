local harness = require("__test__.support.harness")
local process = require("__test__.support.process")
local t = harness.new()

t:test("asynchronous mode changes reach the native screen while the command line is idle", function()
  local result = process.scenario(t, {
    "-n",
    "-i",
    "NONE",
    "--noplugin",
    "--cmd",
    "set background=dark",
    "-u",
    "__test__/fixtures/era/dressing/statusline/cmdline.lua",
  }, { width = 100, height = 24, timeout_ms = 20000 })
  t.assert_eq(0, #result.errors, vim.inspect(result.errors))
  t.assert_false(result.timed_out, vim.inspect(result.current))
  t.assert_eq(3, #result.samples, "NORMAL → COMMAND → NORMAL reaches the screen without extra input")
end)

t:run()
