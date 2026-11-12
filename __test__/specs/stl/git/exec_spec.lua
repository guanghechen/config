local harness = require("__test__.support.harness")
local Future = require("stl.c.future")
local CancellationToken = require("stl.c.cancellation_token")

local t = harness.new()
local git = require("__test__.support.git")

t:patch_global("stl", {
  c = { Future = Future },
})
t:patch_global("yoz", {
  canonical_path = {
    to_os_path = function(filepath)
      return filepath
    end,
  },
})
t:patch_table(vim, "schedule", function(callback)
  callback()
end)

local exec = require("stl.git.exec")

---Replaces `vim.system` with processes that complete at once with `result`, a success without output by default, after
---`inspect` sees each command and its options.
---@param inspect                       fun(cmd: string[], opts: vim.SystemOpts)
---@param result                        ?vim.SystemCompleted
---@return nil
local function complete_system(inspect, result)
  t:patch_table(vim, "system", function(cmd, opts, callback)
    inspect(cmd, opts)
    callback(result or { code = 0, stdout = "", stderr = "" })
    return {}
  end)
end

t:test("exec_async forwards Git stderr on failure", function()
  local command = {} ---@type string[]
  complete_system(function(cmd, opts)
    command = cmd
    t.assert_true(opts.text, "text output")
  end, { code = 128, stdout = "", stderr = "fatal: index is locked\n" })

  local result = nil ---@type table|nil
  exec.exec_async({ "add", "--", "file.txt" }, { cwd = "/repo" }, function(lines, code, stderr)
    result = { lines = lines, code = code, stderr = stderr }
  end)

  t.assert_eq("git -C /repo --literal-pathspecs add -- file.txt", table.concat(command, " "), "command")
  local actual = assert(result, "callback result")
  t.assert_eq(0, #actual.lines, "stdout lines")
  t.assert_eq(128, actual.code, "exit code")
  t.assert_eq("fatal: index is locked\n", actual.stderr, "stderr")
end)

t:test("exec_async forwards NUL-delimited stdin", function()
  complete_system(function(_, opts)
    t.assert_true(opts.text, "text output")
    t.assert_eq("old.lua\0new.lua\0", opts.stdin, "stdin")
  end)

  exec.exec_async(
    { "add", "--pathspec-from-file=-", "--pathspec-file-nul" },
    { cwd = "/repo", stdin = "old.lua\0new.lua\0" },
    function() end
  )
end)

t:test("exec_async converts only the Git working directory to an OS path", function()
  local command = {} ---@type string[]
  t:patch_table(yoz.canonical_path, "to_os_path", function(filepath)
    t.assert_eq("C:/repo", filepath, "canonical cwd")
    return [[C:\repo]]
  end)
  complete_system(function(cmd)
    command = cmd
  end)

  exec.exec_async({ "add", "--", "lua/era/m/git/status.lua" }, { cwd = "C:/repo" }, function() end)

  t.assert_eq([[C:\repo]], command[3], "OS cwd")
  t.assert_eq("lua/era/m/git/status.lua", command[7], "canonical Git pathspec")
end)

t:test("every Git command takes its paths as literal pathspecs", function()
  t.assert_same(
    { "git", "-C", "/repo", "--literal-pathspecs", "log", "--", "a[1].txt" },
    exec.command({ "log", "--", "a[1].txt" }, "/repo"),
    "in a repository"
  )
  t.assert_same(
    { "git", "--literal-pathspecs", "clone", "https://example.test/repo.git", "/repos/example" },
    exec.command({ "clone", "https://example.test/repo.git", "/repos/example" }),
    "without a working directory"
  )
end)

t:test("a file's history and latest commit leave out the files its name matches as a glob", function()
  local repo = git.repo(t)
  vim.fn.writefile({ "x" }, repo .. "/a[1].txt")
  git.commit(repo, "add a[1]")
  vim.fn.writefile({ "y" }, repo .. "/a1.txt")
  git.commit(repo, "add a1")
  vim.fn.writefile({ "y2" }, repo .. "/a1.txt")
  git.commit(repo, "edit a1")

  -- Diffview's file history and the browse permalink ask in these shapes, through exec and exec_sync.
  local history = assert(t.await(exec.exec({ "log", "--follow", "--format=%s", "--", "a[1].txt" }, { cwd = repo })))
  t.assert_same({ "add a[1]" }, history.lines, "history")
  local latest, code = exec.exec_sync({ "log", "-n", "1", "--pretty=format:%s", "--", "a[1].txt" }, { cwd = repo })
  t.assert_eq(0, code, "latest commit exit code")
  t.assert_same({ "add a[1]" }, latest, "latest commit")
end)

t:test("exec_async preserves canonical and native UNC roots", function()
  local commands = {} ---@type string[][]
  t:patch_table(yoz.canonical_path, "to_os_path", function(filepath)
    return filepath:gsub("/", "\\")
  end)
  complete_system(function(cmd)
    commands[#commands + 1] = cmd
  end)

  exec.exec_async({ "status" }, { cwd = "//server/share/repo" }, function() end)
  exec.exec_async({ "status" }, { cwd = [[\\server\share\repo]] }, function() end)

  t.assert_eq([[\\server\share\repo]], commands[1][3], "canonical UNC cwd")
  t.assert_eq([[\\server\share\repo]], commands[2][3], "native UNC cwd")
end)

t:test("exec raw mode preserves CRLF bytes inside NUL-delimited paths", function()
  local repo = git.repo(t)
  local filename = "a\r\nb.lua"
  vim.fn.writefile({ "content" }, repo .. "/" .. filename)
  git.run(repo, { "add", "--", filename })

  local future = exec.exec({ "diff", "--staged", "--name-status", "-z", "--" }, { cwd = repo, raw = true })
  local result = assert(t.await(future), "raw result")
  t.assert_eq(0, result.code, "raw exit code")
  t.assert_eq("A\0" .. filename .. "\0", result.lines[1], "raw stdout")
end)

t:test("exec preserves stderr for failed status queries", function()
  complete_system(function(_, opts)
    t.assert_false(opts.text, "raw output")
  end, { code = 128, stdout = "partial", stderr = "fatal: corrupt index\n" })

  local future = exec.exec({ "diff", "--name-status", "-z" }, { cwd = "/repo", raw = true })
  local result = assert(future:get_result(), "Git result")

  t.assert_eq(128, result.code, "exit code")
  t.assert_eq(0, #result.lines, "failed stdout discarded")
  t.assert_eq("fatal: corrupt index\n", result.stderr, "stderr")
end)

t:test("exec forwards an isolated environment and NUL-delimited stdin", function()
  complete_system(function(_, opts)
    t.assert_false(opts.text, "raw output")
    t.assert_eq("/tmp/index", opts.env.GIT_INDEX_FILE, "environment")
    t.assert_eq("file.txt\0", opts.stdin, "stdin")
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
