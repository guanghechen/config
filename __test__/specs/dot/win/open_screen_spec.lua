--- Timeout: 120000
local harness = require("__test__.support.harness")
local process = require("__test__.support.process")
local t = harness.new()

t:test("native opening preserves saved positions and navigation ownership with UI services", function()
  local directory = t:tempdir()
  local runs = {}
  for _, services in ipairs({ "off", "on" }) do
    local case_dir = directory .. "/" .. services
    vim.fn.mkdir(case_dir, "p")
    local seed = process.script(t, "__test__/fixtures/dot/win/seed_marks.lua", { case_dir })
    t.assert_eq(0, seed.code, seed.stderr)
    t.assert_true(vim.fn.getfsize(case_dir .. "/marks.shada") > 0, "saved file marks fixture")
    local run = process.pty(t, {
      "-n",
      "-i",
      case_dir .. "/marks.shada",
      "--noplugin",
      "-u",
      "__test__/fixtures/dot/win/open_screen.lua",
    }, {
      width = 120,
      height = 32,
      env = {
        NVIM_NOTTYFAST = "1",
        OPEN_TEST_DIR = case_dir,
        OPEN_TEST_SERVICES = services,
        OPEN_TEST_RESULT = case_dir .. "/result.json",
      },
    })
    run.services, run.result_path = services, case_dir .. "/result.json"
    runs[#runs + 1] = run
  end

  process.assert_exited(t, runs, 60000)
  for _, run in ipairs(runs) do
    local result = vim.json.decode(table.concat(vim.fn.readfile(run.result_path), "\n"))
    t.assert_eq(0, #result.failures, vim.inspect(result.failures))
    t.assert_eq(34, #result.samples, "native opening scenarios")
    t.assert_true(result.files_unchanged, "file and buffer contents retained")
    t.assert_nil(result.messages:match("E%d+:"), result.messages)
  end
end)

t:run()
