local harness = require("__test__.support.harness")
local process = require("__test__.support.process")
local t = harness.new()

t:test("batched refreshes reach the native screen while the command line is idle", function()
  local result_path = t:tempdir() .. "/result.json"
  local run = process.pty(
    t,
    { "-n", "-i", "NONE", "--noplugin", "-u", "__test__/fixtures/era/dressing/indentline/screen.lua" },
    { width = 100, height = 24, env = { NVIM_NOTTYFAST = "1", INDENTLINE_TEST_RESULT = result_path } }
  )
  process.assert_exited(t, { run }, 5000)
  local result = vim.json.decode(table.concat(vim.fn.readfile(result_path), "\n"))
  t.assert_false(result.timed_out, vim.inspect(result.current))
  t.assert_eq(6, #result.samples, "initial screen, hidden options and command-line updates completed")
  for _, sample in ipairs(result.samples) do
    t.assert_eq(0, sample.sync_frames, sample.name .. " avoids intermediate redraws")
  end
end)

t:run()
