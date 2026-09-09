--- Run with: nvim -l __test__/run.lua __test__/specs/era/m/git/status_exit_spec.lua
local harness = require("__test__.support.harness")
local t = harness.new("era.m.git.status exit")

t:test("Neovim exit waits for native Git cancellation acknowledgement", function()
  local root = vim.fn.tempname()
  vim.fn.mkdir(root, "p")
  t:defer(function()
    vim.fn.delete(root, "rf")
  end)
  local marker = root .. "/started"
  local hook = root .. "/monitor"
  vim.fn.writefile({ "#!/bin/sh", "echo started > " .. vim.fn.shellescape(marker), "sleep 30" }, hook)
  assert(vim.uv.fs_chmod(hook, 493))

  ---@param args                        string[]
  ---@return nil
  local function git(args)
    local command = { "git", "-C", root }
    vim.list_extend(command, args)
    local result = vim.system(command):wait()
    t.assert_eq(0, result.code, result.stderr)
  end
  git({ "init", "-q" })
  vim.fn.writefile({ "base" }, root .. "/file")
  git({ "add", "file" })
  git({ "config", "core.fsmonitor", hook })

  local repo = vim.uv.cwd()
  local command = {
    vim.v.progpath,
    "--headless",
    "-u",
    "NONE",
    "-i",
    "NONE",
    "-n",
    "-l",
    repo .. "/__test__/fixtures/era/m/git/job_exit.lua",
    repo,
    root,
    marker,
  }
  local result = vim.system(command, { text = true }):wait(10000)
  t.assert_eq(0, result.code, result.stderr)
  t.assert_true(result.stdout:find("native-exit-acknowledged", 1, true) ~= nil, "worker reaped Git before exit")
end)

t:run()
