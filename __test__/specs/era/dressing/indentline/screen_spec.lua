---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.specs.era.dressing.indentline.screen" ---@type string

local harness = require("__test__.support.harness")
local t = harness.new("era.dressing.indentline.screen")

t:test("batched refreshes reach the native screen while the command line is idle", function()
  local root = vim.uv.cwd()
  local dirpath = assert(vim.uv.fs_mkdtemp(root .. "/__test__/local.indentline-screen.XXXXXX"))
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
    "-u",
    root .. "/__test__/fixtures/era/dressing/indentline/screen.lua",
  }, {
    cwd = root,
    pty = true,
    width = 100,
    height = 24,
    env = { TERM = "xterm-256color", NVIM_NOTTYFAST = "1", INDENTLINE_TEST_RESULT = result_path },
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
  t.assert_false(result.timed_out, vim.inspect(result.current))
  t.assert_eq(6, #result.samples, "initial screen, hidden options and command-line updates completed")
  for _, sample in ipairs(result.samples) do
    t.assert_eq(0, sample.sync_frames, sample.name .. " avoids intermediate redraws")
  end
end)

t:run()
