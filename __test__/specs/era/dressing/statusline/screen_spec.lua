local harness = require("__test__.support.harness")
local process = require("__test__.support.process")
local t = harness.new()

t:test("asynchronous mode changes reach the native screen while the command line is idle", function()
  local result_path = t:tempdir() .. "/result.json"
  local run = process.pty(t, {
    "-n",
    "-i",
    "NONE",
    "--noplugin",
    "--cmd",
    "set background=dark",
    "-u",
    "__test__/fixtures/era/dressing/statusline/cmdline.lua",
  }, { width = 100, height = 24, env = { NVIMBAR_TEST_RESULT = result_path } })
  process.assert_exited(t, { run }, 5000)
  local result = vim.json.decode(table.concat(vim.fn.readfile(result_path), "\n"))
  t.assert_eq(0, #result.errors, vim.inspect(result.errors))
  t.assert_false(result.timed_out, vim.inspect(result.current))
  t.assert_eq(3, #result.samples, "NORMAL → COMMAND → NORMAL reaches the screen without extra input")
end)

t:run()
