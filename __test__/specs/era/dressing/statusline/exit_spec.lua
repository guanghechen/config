local harness = require("__test__.support.harness")
local process = require("__test__.support.process")
local t = harness.new()

t:test("quitting Neovim terminates a pending Python probe", function()
  local result_path = t:tempdir() .. "/pid"
  local probe_exited = false
  t:defer(function()
    if not probe_exited and vim.uv.fs_stat(result_path) then
      local pid = tonumber(vim.fn.readfile(result_path)[1])
      if pid then
        vim.uv.kill(pid, 15)
      end
    end
  end)

  local result =
    process.script(t, "__test__/fixtures/era/dressing/statusline/exit.lua", nil, { NVIMBAR_TEST_RESULT = result_path })
  t.assert_eq(0, result.code, result.stderr)
  t.assert_eq("", result.stderr, "exit callbacks do not report errors")
  local pid = assert(tonumber(vim.fn.readfile(result_path)[1]), "probe PID")
  t.wait_until(function()
    return not vim.uv.kill(pid, 0)
  end, 5000, "the Python probe outlived Neovim")
  probe_exited = true
end)

t:run()
