local harness = require("__test__.support.harness")
local t = harness.new("era.dressing.statusline.screen")

t:test("asynchronous mode changes reach the native screen while the command line is idle", function()
  local root = vim.uv.cwd()
  local dirpath = assert(vim.uv.fs_mkdtemp(root .. "/__test__/local.statusline-screen.XXXXXX"))
  t:defer(function()
    vim.fn.delete(dirpath, "rf")
  end)
  local result_path = dirpath .. "/result.json"
  local output, exit_code = {}, nil
  local job = vim.fn.jobstart({
    vim.v.progpath,
    "-n",
    "-i",
    "NONE",
    "--noplugin",
    "--cmd",
    "set background=dark",
    "-u",
    root .. "/__test__/fixtures/era/dressing/statusline/cmdline.lua",
  }, {
    cwd = root,
    pty = true,
    width = 100,
    height = 24,
    env = { TERM = "xterm-256color", NVIMBAR_TEST_RESULT = result_path },
    on_stdout = function(_, data)
      output[#output + 1] = table.concat(data, "\n")
    end,
    on_exit = function(_, code)
      exit_code = code
    end,
  })
  t.assert_true(job > 0, "native Neovim process started")
  t:defer(function()
    if exit_code == nil then
      vim.fn.jobstop(job)
      vim.fn.jobwait({ job }, 1000)
    end
  end)
  local exited = vim.wait(5000, function()
    return exit_code ~= nil
  end)
  t.assert_true(exited, "native Neovim did not exit:\n" .. table.concat(output))
  t.assert_eq(0, exit_code, table.concat(output))
  local result = vim.json.decode(table.concat(vim.fn.readfile(result_path), "\n"))
  t.assert_eq(0, #result.errors, vim.inspect(result.errors))
  t.assert_false(result.timed_out, vim.inspect(result.current))
  t.assert_eq(3, #result.samples, "NORMAL → COMMAND → NORMAL reaches the screen without extra input")
end)

t:run()
