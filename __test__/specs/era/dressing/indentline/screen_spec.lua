local harness = require("__test__.support.harness")
local process = require("__test__.support.process")
local t = harness.new()

t:test("batched refreshes reach the native screen while the command line is idle", function()
  local result = process.scenario(
    t,
    { "-n", "-i", "NONE", "--noplugin", "-u", "__test__/fixtures/era/dressing/indentline/screen.lua" },
    { width = 100, height = 24, env = { NVIM_NOTTYFAST = "1" }, timeout_ms = 30000 }
  )
  t.assert_false(result.timed_out, vim.inspect(result.current))
  t.assert_eq(6, #result.samples, "initial screen, hidden options and command-line updates completed")
  for _, sample in ipairs(result.samples) do
    t.assert_eq(0, sample.sync_frames, sample.name .. " avoids intermediate redraws")
  end
end)

t:run()
