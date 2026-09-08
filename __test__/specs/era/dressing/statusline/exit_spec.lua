local harness = require("__test__.support.harness")
local t = harness.new("era.dressing.statusline.exit")

t:test("quitting Neovim terminates a pending Python probe", function()
  local root = vim.uv.cwd()
  local dirpath = assert(vim.uv.fs_mkdtemp(root .. "/__test__/local.statusline-exit.XXXXXX"))
  t:defer(function()
    vim.fn.delete(dirpath, "rf")
  end)
  local result_path = dirpath .. "/pid"
  local probe_exited = false
  local process = vim.system({
    vim.v.progpath,
    "--headless",
    "-u",
    "NONE",
    "-i",
    "NONE",
    "-n",
    "-l",
    root .. "/__test__/fixtures/era/dressing/statusline/exit.lua",
  }, { text = true, env = { NVIMBAR_TEST_RESULT = result_path } })
  t:defer(function()
    if not process:is_closing() then
      process:kill(15)
      process:wait(1000)
    end
    if not probe_exited and vim.uv.fs_stat(result_path) then
      local pid = tonumber(vim.fn.readfile(result_path)[1])
      if pid then
        vim.uv.kill(pid, 15)
      end
    end
  end)

  local result = process:wait(5000)
  t.assert_eq(0, result.code, result.stderr)
  t.assert_eq("", result.stderr, "exit callbacks do not report errors")
  local pid = assert(tonumber(vim.fn.readfile(result_path)[1]), "probe PID")
  t.wait_until(function()
    return not vim.uv.kill(pid, 0)
  end, 1000, "the Python probe outlived Neovim")
  probe_exited = true
end)

t:run()
