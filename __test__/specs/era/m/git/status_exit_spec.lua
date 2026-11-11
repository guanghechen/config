local harness = require("__test__.support.harness")
local t = harness.new()
local git = require("__test__.support.git")
local process = require("__test__.support.process")

t:test("Neovim exit waits for native Git cancellation acknowledgement", function()
  local root = git.repo(t)
  local marker = root .. "/started"
  local hook = root .. "/monitor"
  vim.fn.writefile({ "#!/bin/sh", "echo started > " .. vim.fn.shellescape(marker), "sleep 30" }, hook)
  assert(vim.uv.fs_chmod(hook, 493))

  vim.fn.writefile({ "base" }, root .. "/file")
  git.run(root, { "add", "file" })
  git.run(root, { "config", "core.fsmonitor", hook })

  local repo = assert(vim.uv.cwd())
  local result = process.script(t, "__test__/fixtures/era/m/git/job_exit.lua", { repo, root, marker })
  t.assert_eq(0, result.code, result.stderr)
  t.assert_true(result.stdout:find("native-exit-acknowledged", 1, true) ~= nil, "worker reaped Git before exit")
end)

t:run()
