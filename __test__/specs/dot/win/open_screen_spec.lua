---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.specs.dot.win.open_screen" ---@type string

local harness = require("__test__.support.harness")
local t = harness.new("dot.win.open_screen")

t:test("native opening preserves saved positions and navigation ownership with UI services", function()
  local root = vim.uv.cwd()
  local directory = assert(vim.uv.fs_mkdtemp(root .. "/__test__/local.open-screen.XXXXXX"))
  t:defer(function()
    vim.fn.delete(directory, "rf")
  end)
  local runs = {}
  for _, services in ipairs({ "off", "on" }) do
    local case_dir = directory .. "/" .. services
    vim.fn.mkdir(case_dir, "p")
    local seed = vim
      .system({
        vim.v.progpath,
        "--headless",
        "-u",
        "NONE",
        "-i",
        "NONE",
        "-n",
        "-l",
        root .. "/__test__/fixtures/dot/win/seed_marks.lua",
        case_dir,
      }, { text = true })
      :wait(5000)
    t.assert_eq(0, seed.code, seed.stderr)
    t.assert_true(vim.fn.getfsize(case_dir .. "/marks.shada") > 0, "saved file marks fixture")

    local run = { output = {}, result_path = case_dir .. "/result.json", services = services }
    local job = vim.fn.jobstart({
      vim.v.progpath,
      "-n",
      "-i",
      case_dir .. "/marks.shada",
      "--noplugin",
      "-u",
      root .. "/__test__/fixtures/dot/win/open_screen.lua",
    }, {
      cwd = root,
      pty = true,
      width = 120,
      height = 32,
      env = {
        TERM = "xterm-256color",
        NVIM_NOTTYFAST = "1",
        OPEN_TEST_DIR = case_dir,
        OPEN_TEST_SERVICES = services,
        OPEN_TEST_RESULT = run.result_path,
      },
      on_stdout = function(_, data)
        run.output[#run.output + 1] = table.concat(data, "\n")
      end,
      on_exit = function(_, code)
        run.exit_code = code
      end,
    })
    t.assert_true(job > 0, "native Neovim process started")
    t:defer(function()
      if run.exit_code == nil then
        vim.fn.jobstop(job)
        vim.fn.jobwait({ job }, 1000)
      end
    end)
    runs[#runs + 1] = run
  end

  local exited = vim.wait(20000, function()
    for _, run in ipairs(runs) do
      if run.exit_code == nil then
        return false
      end
    end
    return true
  end)
  for _, run in ipairs(runs) do
    local output = table.concat(run.output)
    t.assert_true(exited, "native process timed out (services=" .. run.services .. "):\n" .. output)
    t.assert_eq(0, run.exit_code, output)
    local result = vim.json.decode(table.concat(vim.fn.readfile(run.result_path), "\n"))
    t.assert_eq(0, #result.failures, vim.inspect(result.failures))
    t.assert_eq(34, #result.samples, "native opening scenarios")
    t.assert_true(result.files_unchanged, "file and buffer contents retained")
    t.assert_nil(result.messages:match("E%d+:"), result.messages)
  end
end)

t:run()
