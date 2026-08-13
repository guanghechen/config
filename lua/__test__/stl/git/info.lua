---@diagnostic disable: undefined-global
--- Test for stl.git.info module
--- Run with: nvim -l lua/__test__/stl/git/info.lua

local bootstrap = require("__test__.bootstrap")
local CancellationToken = require("stl.c.cancellation_token")
local Future = require("stl.c.future")
local harness = require("__test__.harness")
local native = require("yoz")

local t = harness.new("stl.git.info")

---@param repo                         string
---@param ...                          string
---@return vim.SystemCompleted
local function git(repo, ...)
  return vim.system({ "git", "-C", repo, ... }, { text = true }):wait()
end

bootstrap.with_runtime(t, {
  stl = {
    c = { Future = Future },
    env = { PATH_SEP = "/" },
  },
  yoz = {
    canonical_path = {
      to_os_path = function(filepath)
        return filepath
      end,
    },
    path = {
      normalize = function(path)
        return path
      end,
    },
  },
})

local info = require("stl.git.info")

---@class stl.git.info.test.IProcess
---@field public killed                boolean
---@field public kill                  fun(self: stl.git.info.test.IProcess): nil

---@class stl.git.info.test.IRequest
---@field public argv                  string[]
---@field public callback              fun(obj: table): nil
---@field public proc                  stl.git.info.test.IProcess

---@return stl.git.info.test.IRequest[]
local function mock_system()
  local requests = {} ---@type stl.git.info.test.IRequest[]
  t:patch_table(vim, "system", function(argv, _, callback)
    local proc = { killed = false } ---@type stl.git.info.test.IProcess
    function proc:kill()
      self.killed = true
    end
    requests[#requests + 1] = { argv = argv, callback = callback, proc = proc }
    return proc
  end)
  return requests
end

---@param future stl.c.Future
local function wait_future(future)
  t.wait_until(function()
    return future:is_done()
  end, 1000, "future should resolve")
end

t:test("filesystem and Git boundaries convert canonical roots without changing revision paths", function()
  local opened = nil ---@type string|nil
  local requests = mock_system()
  t:patch_table(yoz.canonical_path, "to_os_path", function(filepath)
    return filepath:gsub("/", "\\")
  end)
  t:patch_table(io, "open", function(filepath)
    opened = filepath
    return {
      close = function() end,
      read = function()
        return "ref: refs/heads/main"
      end,
    }
  end)

  t.assert_eq("ref: refs/heads/main", info.head("C:/repo"), "HEAD content")
  t.assert_eq([[C:\repo\.git\HEAD]], opened, "OS filesystem path")

  local future = info.get_show_blob("C:/repo", "HEAD:lua/era/m/git/status.lua")
  t.assert_eq([[C:\repo]], requests[1].argv[3], "OS Git cwd")
  t.assert_eq("HEAD:lua/era/m/git/status.lua", requests[1].argv[6], "canonical revision path")
  requests[1].callback({ code = 0, stdout = "content" })
  wait_future(future)
  t.assert_true(future:get_result().ok, "blob result")

  local unc_future = info.get_show_blob("//server/share/repo", "HEAD:lua/era/m/git/status.lua")
  t.assert_eq([[\\server\share\repo]], requests[2].argv[3], "UNC Git cwd")
  requests[2].callback({ code = 0, stdout = "content" })
  wait_future(unc_future)
  t.assert_true(unc_future:get_result().ok, "UNC blob result")
end)

t:test("canonical Windows-style roots keep nested HEAD paths slash-only with real Git", function()
  local sep = package.config:sub(1, 1) ---@type string
  local repo = vim.fn.tempname() ---@type string
  local canonical_repo = native.path.normalize(repo, false, "/") ---@type string
  local relpath = "lua/era/m/im/wsl.lua" ---@type string
  local filepath = native.path.normalize(canonical_repo .. "/" .. relpath, false, sep) ---@type string
  t:patch_table(yoz.canonical_path, "to_os_path", function(path)
    return path:gsub("/", sep)
  end)

  vim.fn.mkdir(vim.fs.dirname(filepath), "p")
  local ok, err = xpcall(function()
    t.assert_eq(0, git(repo, "init", "-q").code, "git init")
    vim.fn.writefile({ "content" }, filepath)
    t.assert_eq(0, git(repo, "add", "--", relpath).code, "git add")
    t.assert_eq(
      0,
      git(repo, "-c", "user.name=Test", "-c", "user.email=test@example.com", "commit", "-qm", "base").code,
      "git commit"
    )

    local future = info.get_show_blob(canonical_repo, "HEAD:" .. relpath)
    wait_future(future)

    local result = future:get_result()
    t.assert_true(result.ok, "HEAD blob")
    t.assert_eq("content\n", result.bytes, "HEAD bytes")
  end, debug.traceback)

  vim.fn.delete(repo, "rf")
  if not ok then
    error(err)
  end
end)

t:test("get_object_name: resolves immutable identity and classifies absence", function()
  local requests = mock_system()
  local present = info.get_object_name("/work", "HEAD:f.txt")

  t.assert_eq(
    "git -C /work rev-parse --verify --quiet HEAD:f.txt",
    table.concat(requests[1].argv, " "),
    "resolution command"
  )
  requests[1].callback({ code = 0, stdout = "abc123\n" })
  wait_future(present)
  local present_result = present:get_result()
  t.assert_true(present_result.ok, "resolved")
  t.assert_false(present_result.missing, "present")
  t.assert_eq("abc123", present_result.object_name, "object identity")

  local missing = info.get_object_name("/work", "HEAD:missing.txt")
  requests[2].callback({ code = 1, stdout = "" })
  wait_future(missing)
  local missing_result = missing:get_result()
  t.assert_false(missing_result.ok, "not resolved")
  t.assert_true(missing_result.missing, "missing")

  local failed = info.get_object_name("/work", "HEAD:f.txt")
  requests[3].callback({ code = 128, stderr = "injected resolution failure" })
  wait_future(failed)
  local failed_result = failed:get_result()
  t.assert_false(failed_result.ok, "failed")
  t.assert_false(failed_result.missing, "failure is not absence")
  t.assert_true(failed_result.err:find("injected resolution failure", 1, true) ~= nil, "actionable error")
end)

t:test("get_object_name: cancellation kills resolution and returns failure", function()
  local requests = mock_system()
  local token = CancellationToken.new()
  local future = info.get_object_name("/work", "HEAD:f.txt", token)

  token:cancel()
  wait_future(future)

  local result = future:get_result()
  t.assert_true(requests[1].proc.killed, "resolution killed")
  t.assert_false(result.ok, "not resolved")
  t.assert_false(result.missing, "cancellation is not absence")
  t.assert_eq("Operation cancelled", result.err, "error")
end)

t:test("get_show_blob: returns raw bytes", function()
  local requests = mock_system()
  local future = info.get_show_blob("/work", "abc123")

  requests[1].callback({ code = 0, stdout = "a\0b\n" })
  wait_future(future)

  local result = future:get_result()
  t.assert_true(result.ok, "read")
  t.assert_false(result.missing, "not missing")
  t.assert_eq("a\0b\n", result.bytes, "bytes")
  t.assert_eq(1, #requests, "process count")
end)

t:test("get_show_blob: treats an absent unmerged stage as missing", function()
  local requests = mock_system()
  local future = info.get_show_blob("/work", ":2:f.txt")

  requests[1].callback({ code = 128, stderr = "fatal: path is not at stage 2" })
  t.wait_until(function()
    return #requests == 2
  end, 1000, "stage inspection should start")
  t.assert_eq(
    "git -C /work --literal-pathspecs ls-files --stage -z -- f.txt",
    table.concat(requests[2].argv, " "),
    "stage inspection command"
  )
  requests[2].callback({ code = 0, stdout = "100644 abc123 3\tf.txt\0" })
  wait_future(future)

  local result = future:get_result()
  t.assert_false(result.ok, "not read")
  t.assert_true(result.missing, "missing stage")
end)

t:test("get_show_blob: confirms a missing revision path with ls-tree", function()
  local requests = mock_system()
  local future = info.get_show_blob("/work", "HEAD:missing.txt")

  requests[1].callback({ code = 128, stderr = "fatal: path does not exist" })
  t.wait_until(function()
    return #requests == 2
  end, 1000, "ls-tree should start")
  t.assert_eq(
    "git -C /work --literal-pathspecs ls-tree HEAD -- missing.txt",
    table.concat(requests[2].argv, " "),
    "command"
  )
  requests[2].callback({ code = 0, stdout = "" })
  wait_future(future)

  local result = future:get_result()
  t.assert_false(result.ok, "not read")
  t.assert_true(result.missing, "missing")
end)

t:test("get_show_blob: treats an unborn revision as missing", function()
  local requests = mock_system()
  local future = info.get_show_blob("/work", "HEAD:f.txt")

  requests[1].callback({ code = 128, stderr = "fatal: invalid object name 'HEAD'" })
  t.wait_until(function()
    return #requests == 2
  end, 1000, "ls-tree should start")
  requests[2].callback({ code = 128, stderr = "fatal: Not a valid object name HEAD" })
  t.wait_until(function()
    return #requests == 3
  end, 1000, "revision verification should start")
  t.assert_eq(
    "git -C /work rev-parse --verify --quiet HEAD",
    table.concat(requests[3].argv, " "),
    "verification command"
  )
  requests[3].callback({ code = 1, stdout = "" })
  wait_future(future)

  local result = future:get_result()
  t.assert_false(result.ok, "not read")
  t.assert_true(result.missing, "unborn revision")
end)

t:test("get_show_blob: preserves tree inspection failure when the revision exists", function()
  local requests = mock_system()
  local future = info.get_show_blob("/work", "HEAD:f.txt")

  requests[1].callback({ code = 128, stderr = "injected read failure" })
  t.wait_until(function()
    return #requests == 2
  end, 1000, "ls-tree should start")
  requests[2].callback({ code = 128, stderr = "injected tree failure" })
  t.wait_until(function()
    return #requests == 3
  end, 1000, "revision verification should start")
  requests[3].callback({ code = 0, stdout = "abc123\n" })
  wait_future(future)

  local result = future:get_result()
  t.assert_false(result.ok, "not read")
  t.assert_false(result.missing, "revision exists")
  t.assert_true(result.err:find("injected tree failure", 1, true) ~= nil, "tree error")
end)

t:test("get_show_blob: an existing revision path read failure is not missing", function()
  local requests = mock_system()
  local future = info.get_show_blob("/work", "HEAD:f.txt")

  requests[1].callback({ code = 128, stderr = "injected read failure" })
  t.wait_until(function()
    return #requests == 2
  end, 1000, "ls-tree should start")
  requests[2].callback({ code = 0, stdout = "100644 blob abc123\tf.txt\n" })
  wait_future(future)

  local result = future:get_result()
  t.assert_false(result.ok, "not read")
  t.assert_false(result.missing, "existing path")
  t.assert_true(result.err:find("injected read failure", 1, true) ~= nil, "read error")
end)

t:test("get_show_blob: confirms a missing index path with ls-files", function()
  local requests = mock_system()
  local future = info.get_show_blob("/work", ":missing.txt")

  requests[1].callback({ code = 128, stderr = "fatal: path does not exist" })
  t.wait_until(function()
    return #requests == 2
  end, 1000, "ls-files should start")
  t.assert_eq(
    "git -C /work --literal-pathspecs ls-files --error-unmatch -- missing.txt",
    table.concat(requests[2].argv, " "),
    "command"
  )
  requests[2].callback({ code = 1, stdout = "" })
  wait_future(future)

  local result = future:get_result()
  t.assert_false(result.ok, "not read")
  t.assert_true(result.missing, "missing")
end)

t:test("get_show_blob: raw object failure is never missing", function()
  local requests = mock_system()
  local future = info.get_show_blob("/work", "abc123")

  requests[1].callback({ code = 128, stderr = "injected read failure" })
  wait_future(future)

  local result = future:get_result()
  t.assert_false(result.ok, "not read")
  t.assert_false(result.missing, "not missing")
  t.assert_eq(1, #requests, "no existence fallback")
end)

t:test("get_show_blob: cancellation kills classification and returns failure", function()
  local requests = mock_system()
  local token = CancellationToken.new()
  local future = info.get_show_blob("/work", "HEAD:f.txt", token)

  requests[1].callback({ code = 128, stderr = "injected read failure" })
  t.wait_until(function()
    return #requests == 2
  end, 1000, "ls-tree should start")
  token:cancel()
  wait_future(future)

  local result = future:get_result()
  t.assert_true(requests[2].proc.killed, "classification killed")
  t.assert_false(result.ok, "not read")
  t.assert_false(result.missing, "cancellation is not missing")
  t.assert_eq("Operation cancelled", result.err, "error")
end)

t:test("get_file_info: distinguishes an index entry from a missing path", function()
  local requests = mock_system()
  local present = info.get_file_info("/work", "f.txt")

  requests[1].callback({ code = 0, stdout = "100755 abc123 0\tf.txt\n" })
  wait_future(present)
  local present_result = present:get_result()
  t.assert_true(present_result.ok, "entry")
  t.assert_false(present_result.missing, "present")
  t.assert_eq("100755", present_result.info.mode_bits, "mode")
  t.assert_eq("abc123", present_result.info.object_name, "object")

  local missing = info.get_file_info("/work", "missing.txt")
  requests[2].callback({ code = 0, stdout = "" })
  wait_future(missing)
  local missing_result = missing:get_result()
  t.assert_false(missing_result.ok, "no entry")
  t.assert_true(missing_result.missing, "missing")
end)

t:test("get_file_info: command failure is not missing", function()
  local requests = mock_system()
  local future = info.get_file_info("/work", "f.txt")

  requests[1].callback({ code = 128, stderr = "injected index failure" })
  wait_future(future)

  local result = future:get_result()
  t.assert_false(result.ok, "failed")
  t.assert_false(result.missing, "not missing")
  t.assert_true(result.err:find("injected index failure", 1, true) ~= nil, "error")
end)

t:test("get_file_info: reports unmerged entries explicitly", function()
  local requests = mock_system()
  local future = info.get_file_info("/work", "f.txt")

  requests[1].callback({ code = 0, stdout = "100644 abc123 1\tf.txt\n100644 def456 2\tf.txt\n" })
  wait_future(future)

  local result = future:get_result()
  t.assert_true(result.ok, "inspected")
  t.assert_true(result.info.has_conflicts, "unmerged")
  t.assert_nil(result.info.object_name, "no stage-zero object")
end)

t:test("get_head_file_mode: distinguishes mode, missing path, unborn HEAD, and failure", function()
  local requests = mock_system()
  local present = info.get_head_file_mode("/work", "f.txt")

  requests[1].callback({ code = 0, stdout = "100755 blob abc123\tf.txt\n" })
  wait_future(present)
  local present_result = present:get_result()
  t.assert_true(present_result.ok, "mode")
  t.assert_eq("100755", present_result.mode_bits, "mode bits")

  local missing = info.get_head_file_mode("/work", "missing.txt")
  requests[2].callback({ code = 0, stdout = "" })
  wait_future(missing)
  local missing_result = missing:get_result()
  t.assert_false(missing_result.ok, "no mode")
  t.assert_true(missing_result.missing, "missing")

  local unborn = info.get_head_file_mode("/work", "f.txt")
  requests[3].callback({ code = 128, stderr = "injected tree failure" })
  t.wait_until(function()
    return #requests == 4
  end, 1000, "HEAD verification should start")
  requests[4].callback({ code = 1, stdout = "" })
  wait_future(unborn)
  local unborn_result = unborn:get_result()
  t.assert_false(unborn_result.ok, "no mode")
  t.assert_true(unborn_result.missing, "unborn HEAD")

  local failed = info.get_head_file_mode("/work", "f.txt")
  requests[5].callback({ code = 128, stderr = "injected tree failure" })
  t.wait_until(function()
    return #requests == 6
  end, 1000, "HEAD verification should start")
  requests[6].callback({ code = 0, stdout = "abc123\n" })
  wait_future(failed)
  local failed_result = failed:get_result()
  t.assert_false(failed_result.ok, "failed")
  t.assert_false(failed_result.missing, "not missing")
  t.assert_true(failed_result.err:find("injected tree failure", 1, true) ~= nil, "error")
end)

t:test("path queries treat pathspec-magic filenames literally", function()
  local repo = vim.fn.tempname() ---@type string
  vim.fn.mkdir(repo, "p")

  local ok, err = xpcall(function()
    local magic = ":(glob)o*.txt" ---@type string
    t.assert_eq(0, git(repo, "init", "-q").code, "git init")
    vim.fn.writefile({ "magic" }, repo .. "/" .. magic)
    vim.fn.writefile({ "other" }, repo .. "/other.txt")
    t.assert_true(vim.uv.fs_chmod(repo .. "/" .. magic, 493), "make magic path executable")
    t.assert_eq(0, git(repo, "add", "--all").code, "git add")
    t.assert_eq(
      0,
      git(repo, "-c", "user.name=Test", "-c", "user.email=test@example.com", "commit", "-qm", "base").code,
      "git commit"
    )

    local expected_object = vim.trim(git(repo, "rev-parse", "HEAD:" .. magic).stdout or "") ---@type string
    local file_future = info.get_file_info(repo, magic)
    wait_future(file_future)
    local file_result = file_future:get_result()
    t.assert_true(file_result.ok, "index path found")
    t.assert_eq(expected_object, file_result.info.object_name, "exact index object")

    local mode_future = info.get_head_file_mode(repo, magic)
    wait_future(mode_future)
    local mode_result = mode_future:get_result()
    t.assert_true(mode_result.ok, "HEAD path found")
    t.assert_eq("100755", mode_result.mode_bits, "exact HEAD mode")
  end, debug.traceback)

  vim.fn.delete(repo, "rf")
  if not ok then
    error(err)
  end
end)

t:test("get_repo_info: resolves a branch with one process", function()
  local requests = mock_system()
  local future = info.get_repo_info("/work")

  t.assert_eq(1, #requests, "process count")
  t.assert_eq(
    "git -C /work rev-parse --show-toplevel --absolute-git-dir --abbrev-ref HEAD",
    table.concat(requests[1].argv, " "),
    "command"
  )

  requests[1].callback({ code = 0, stdout = "/repo\n/repo/.git\nmain\n" })
  wait_future(future)

  local result = future:get_result()
  t.assert_eq("/repo", result.toplevel, "toplevel")
  t.assert_eq("/repo/.git", result.gitdir, "gitdir")
  t.assert_eq("main", result.abbrev_head, "abbrev head")
  t.assert_false(result.detached, "detached")
  t.assert_eq(1, #requests, "final process count")
end)

t:test("get_repo_info: resolves detached HEAD with one fallback", function()
  local requests = mock_system()
  local future = info.get_repo_info("/work")

  requests[1].callback({ code = 0, stdout = "/repo\n/repo/.git\nHEAD\n" })
  t.wait_until(function()
    return #requests == 2
  end, 1000, "short HEAD process should start")
  t.assert_eq("git -C /repo rev-parse --short HEAD", table.concat(requests[2].argv, " "), "fallback command")

  requests[2].callback({ code = 0, stdout = "1a2b3c4\n" })
  wait_future(future)

  local result = future:get_result()
  t.assert_eq("1a2b3c4", result.abbrev_head, "abbrev head")
  t.assert_true(result.detached, "detached")
end)

t:test("get_repo_info: preserves unborn repository discovery", function()
  local requests = mock_system()
  local future = info.get_repo_info("/work")

  requests[1].callback({ code = 128, stdout = "/repo\n/repo/.git\nHEAD\n" })
  wait_future(future)

  local result = future:get_result()
  t.assert_eq("/repo", result.toplevel, "toplevel")
  t.assert_eq("", result.abbrev_head, "abbrev head")
  t.assert_false(result.detached, "detached")
  t.assert_eq(1, #requests, "process count")
end)

t:test("get_repo_info: returns nil when discovery fails", function()
  local requests = mock_system()
  local future = info.get_repo_info("/work")

  requests[1].callback({ code = 128, stdout = "" })
  wait_future(future)

  t.assert_nil(future:get_result(), "repo info")
end)

t:test("get_repo_info: cancellation kills detached fallback and resolves nil", function()
  local requests = mock_system()
  local token = CancellationToken.new()
  local future = info.get_repo_info("/work", token)

  requests[1].callback({ code = 0, stdout = "/repo\n/repo/.git\nHEAD\n" })
  t.wait_until(function()
    return #requests == 2
  end, 1000, "short HEAD process should start")

  token:cancel()
  t.assert_true(requests[2].proc.killed, "fallback process should be killed")
  t.assert_true(future:is_resolved(), "cancelled future should resolve")
  t.assert_nil(future:get_result(), "cancelled result")

  requests[2].callback({ code = 0, stdout = "late123\n" })
  vim.wait(10)
  t.assert_nil(future:get_result(), "late result should be ignored")
end)

t:run()
