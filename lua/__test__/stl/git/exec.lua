---@diagnostic disable: undefined-global
--- Run with: nvim -l lua/__test__/stl/git/exec.lua

local harness = require("__test__.harness")
local Future = require("stl.c.future")
local CancellationToken = require("stl.c.cancellation_token")

local t = harness.new("stl.git.exec")

t:patch_global("stl", { c = { Future = Future } })
t:patch_table(vim, "schedule", function(callback)
  callback()
end)

local exec = require("stl.git.exec")

t:test("exec_async forwards Git stderr on failure", function()
  local command = {} ---@type string[]
  t:patch_table(vim, "system", function(cmd, opts, callback)
    command = cmd
    t.assert_true(opts.text, "text output")
    callback({ code = 128, stdout = "", stderr = "fatal: index is locked\n" })
    return {}
  end)

  local result = nil ---@type table|nil
  exec.exec_async({ "add", "--", "file.txt" }, { cwd = "/repo" }, function(lines, code, stderr)
    result = { lines = lines, code = code, stderr = stderr }
  end)

  t.assert_eq("git -C /repo add -- file.txt", table.concat(command, " "), "command")
  local actual = assert(result, "callback result")
  t.assert_eq(0, #actual.lines, "stdout lines")
  t.assert_eq(128, actual.code, "exit code")
  t.assert_eq("fatal: index is locked\n", actual.stderr, "stderr")
end)

t:test("exec raw mode preserves CRLF bytes inside NUL-delimited paths", function()
  local repo = vim.fn.tempname() ---@type string
  local filename = "a\r\nb.lua"
  vim.fn.mkdir(repo, "p")

  local ok, err = xpcall(function()
    t.assert_eq(0, vim.system({ "git", "-C", repo, "init", "-q" }):wait().code, "git init")
    vim.fn.writefile({ "content" }, repo .. "/" .. filename)
    t.assert_eq(0, vim.system({ "git", "-C", repo, "add", "--", filename }):wait().code, "git add")

    local future = exec.exec({ "diff", "--staged", "--name-status", "-z", "--" }, { cwd = repo, raw = true })
    t.wait_until(function()
      return future:is_done()
    end, 5000, "raw Git command")

    local result = assert(future:get_result(), "raw result")
    t.assert_eq(0, result.code, "raw exit code")
    t.assert_eq("A\0" .. filename .. "\0", result.lines[1], "raw stdout")
  end, debug.traceback)

  vim.fn.delete(repo, "rf")
  if not ok then
    error(err)
  end
end)

t:test("exec preserves stderr for failed status queries", function()
  t:patch_table(vim, "system", function(_, opts, callback)
    t.assert_false(opts.text, "raw output")
    callback({ code = 128, stdout = "partial", stderr = "fatal: corrupt index\n" })
    return {}
  end)

  local future = exec.exec({ "diff", "--name-status", "-z" }, { cwd = "/repo", raw = true })
  local result = assert(future:get_result(), "Git result")

  t.assert_eq(128, result.code, "exit code")
  t.assert_eq(0, #result.lines, "failed stdout discarded")
  t.assert_eq("fatal: corrupt index\n", result.stderr, "stderr")
end)

t:test("exec forwards an isolated environment and NUL-delimited stdin", function()
  t:patch_table(vim, "system", function(_, opts, callback)
    t.assert_false(opts.text, "raw output")
    t.assert_eq("/tmp/index", opts.env.GIT_INDEX_FILE, "environment")
    t.assert_eq("file.txt\0", opts.stdin, "stdin")
    callback({ code = 0, stdout = "", stderr = "" })
    return {}
  end)

  local future = exec.exec(
    { "add", "-N", "--pathspec-from-file=-", "--pathspec-file-nul" },
    { cwd = "/repo", raw = true, env = { GIT_INDEX_FILE = "/tmp/index" }, stdin = "file.txt\0" }
  )
  local result = assert(future:get_result(), "Git result")

  t.assert_eq(0, result.code, "exit code")
end)

t:test("exec settles when a running command is cancelled", function()
  local callback = nil ---@type fun(result: table)|nil
  local killed = false
  t:patch_table(vim, "system", function(_, _, value)
    callback = value
    return {
      kill = function(_, signal)
        killed = signal == 9
      end,
    }
  end)

  local token = CancellationToken.new()
  local future = exec.exec({ "diff", "--name-status" }, { cwd = "/repo" }, token)
  t.assert_false(future:is_done(), "command initially pending")

  token:cancel()

  t.assert_true(killed, "process killed")
  t.assert_true(future:is_done(), "cancelled command settled")
  local result = assert(future:get_result(), "cancel result")
  t.assert_eq(-1, result.code, "cancel exit code")
  t.assert_eq("Operation cancelled", result.stderr, "cancel reason")

  assert(callback)({ code = 0, stdout = "late output", stderr = "" })
  t.assert_eq(-1, assert(future:get_result()).code, "late process completion ignored")
end)

t:run()
