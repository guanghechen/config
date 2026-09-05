--- Run with: nvim -l __test__/run.lua __test__/specs/era/m/git/status_collect_spec.lua
---@diagnostic disable: undefined-global

local bootstrap = require("__test__.support.bootstrap")
local harness = require("__test__.support.harness")
local async = require("stl.async")
local RealFuture = require("stl.c.future")

local t = harness.new("era.m.git.status_collect")

local Future = {}

---@param executor                     fun(resolve: fun(result: any), reject: fun(err: string))
---@return table
function Future.new(executor)
  local result = nil ---@type any
  local err = nil ---@type string|nil
  executor(function(value)
    result = value
  end, function(value)
    err = value
  end)
  return {
    get_result = function()
      return result
    end,
    get_error = function()
      return err
    end,
  }
end

---@param value                        any
---@return table
function Future.resolve(value)
  return {
    get_result = function()
      return value
    end,
  }
end

---@param futures                      table[]
---@return table
function Future.all(futures)
  return {
    await = function()
      return futures
    end,
  }
end

local commands = {} ---@type string[][]
local command_opts = {} ---@type stl.git.exec.IExecOpts[]
local responses = {} ---@type table[]
local canonical_normalize_calls = 0 ---@type integer
bootstrap.with_global(t, "stl", {
  env = { PATH_SEP = "/" },
  async = {
    run = function(callback)
      callback()
    end,
  },
  c = { Future = Future },
  git = {
    exec = {
      exec = function(args, opts)
        commands[#commands + 1] = args
        command_opts[#command_opts + 1] = opts
        return responses[#commands] or { code = 0, lines = {} }
      end,
    },
  },
})
bootstrap.with_global(t, "yoz", {
  canonical_path = {
    normalize = function(path)
      canonical_normalize_calls = canonical_normalize_calls + 1
      return path:gsub("\\", "/"):gsub("/+", "/"):gsub("/+$", "")
    end,
  },
})
bootstrap.with_global(t, "dot", {
  path = {
    is_git_repo = function()
      return true
    end,
    workspace = function()
      return "/repo"
    end,
    join = function(left, right)
      return left .. "/" .. right
    end,
    normalize = function(path)
      return path
    end,
  },
})

local status = assert(loadfile("lua/era/m/git/status.lua"))()

---@param args                         string[]
---@param opts                         stl.git.exec.IExecOpts
---@return stl.git.exec.IResult
local function exec_real_git(args, opts)
  local cmd = { "git", "-C", assert(opts.cwd) }
  vim.list_extend(cmd, args)
  local result = vim.system(cmd, { text = false }):wait()
  return {
    code = result.code,
    lines = result.code == 0 and result.stdout ~= "" and { result.stdout } or {},
    stderr = result.stderr or "",
  }
end

t:test("collect: default staged diff does not require HEAD", function()
  commands = {}
  command_opts = {}
  responses = {
    { code = 0, lines = { ":100644 100644 aaaaaaa bbbbbbb M\0staged.lua\0" } },
    { code = 0, lines = { ":100644 100644 ccccccc 0000000 M\0unstaged.lua\0" } },
    { code = 0, lines = {} },
  }
  local result = status.collect(nil):get_result()

  t.assert_true(result ~= nil, "collection result")
  t.assert_eq("diff --staged --raw --abbrev=64 -z --", table.concat(commands[1], " "), "staged command")
  t.assert_eq("diff --raw --abbrev=64 -z --", table.concat(commands[2], " "), "unstaged command")
  t.assert_eq("ls-files --exclude-standard --others -z", table.concat(commands[3], " "), "untracked command")
  t.assert_true(command_opts[1].raw, "staged raw output")
  t.assert_true(command_opts[2].raw, "unstaged raw output")
  t.assert_true(command_opts[3].raw, "untracked raw output")
  t.assert_eq("aaaaaaa", result.status_map["/repo/staged.lua"].staged_old_object_name, "staged source identity")
  t.assert_eq("bbbbbbb", result.status_map["/repo/staged.lua"].staged_new_object_name, "staged target identity")
  t.assert_eq("ccccccc", result.status_map["/repo/unstaged.lua"].unstaged_old_object_name, "index identity")
  t.assert_nil(result.status_map["/repo/unstaged.lua"].unstaged_new_object_name, "worktree identity omitted")
end)

t:test("collect: explicit base remains supported", function()
  commands = {}
  command_opts = {}
  responses = {}
  status.collect({ base = "HEAD" }):get_result()

  t.assert_eq("diff --staged --raw --abbrev=64 -z HEAD --", table.concat(commands[1], " "), "staged command")
end)

t:test("collect: canonicalizes a Windows workspace once without changing Git cwd", function()
  commands = {}
  command_opts = {}
  responses = {
    {
      code = 0,
      lines = {
        ":100644 100644 aaaaaaa bbbbbbb M\0dir/one.lua\0" .. ":000000 100644 0000000 ccccccc A\0two.lua\0",
      },
    },
    { code = 0, lines = { ":100644 100644 bbbbbbb 0000000 M\0dir/one.lua\0" } },
    { code = 0, lines = { "untracked.lua\0" } },
  }
  canonical_normalize_calls = 0
  t:patch_table(stl.env, "PATH_SEP", "\\")
  t:patch_table(dot.path, "workspace", function()
    return [[C:\repo]]
  end)

  local result = status.collect(nil):get_result()

  t.assert_eq(1, canonical_normalize_calls, "workspace normalization")
  t.assert_eq([[C:\repo]], command_opts[1].cwd, "staged Git cwd")
  t.assert_eq([[C:\repo]], command_opts[2].cwd, "unstaged Git cwd")
  t.assert_eq([[C:\repo]], command_opts[3].cwd, "untracked Git cwd")
  t.assert_true(result.status_map["C:/repo/dir/one.lua"] ~= nil, "nested canonical key")
  t.assert_true(result.status_map["C:/repo/two.lua"] ~= nil, "root canonical key")
  t.assert_true(result.status_map["C:/repo/untracked.lua"] ~= nil, "untracked canonical key")
end)

t:test("collect: optional numstat mode returns one coherent tracked snapshot", function()
  commands = {}
  command_opts = {}
  responses = {
    {
      code = 0,
      lines = {
        ":100644 100644 aaaaaaa bbbbbbb M\0normal.lua\0"
          .. ":100644 100644 aaaaaaa bbbbbbb R100\0old\tname.lua\0new\tname.lua\0"
          .. ":100644 100644 aaaaaaa bbbbbbb M\0binary.dat\0"
          .. "3\t1\tnormal.lua\0"
          .. "4\t2\t\0old\tname.lua\0new\tname.lua\0"
          .. "-\t-\tbinary.dat\0",
      },
    },
    {
      code = 0,
      lines = {
        ":100644 000000 aaaaaaa 0000000 D\0deleted.lua\0" .. "0\t5\tdeleted.lua\0",
      },
    },
    { code = 0, lines = { "fresh\nfile.lua\0" } },
  }

  local result = status.collect({ include_numstat = true }):get_result()

  t.assert_eq("diff --staged --raw --abbrev=64 --numstat -z --", table.concat(commands[1], " "), "staged snapshot")
  t.assert_eq("diff --raw --abbrev=64 --numstat -z --", table.concat(commands[2], " "), "unstaged snapshot")
  t.assert_eq("ls-files --exclude-standard --others -z", table.concat(commands[3], " "), "untracked snapshot")
  t.assert_true(command_opts[1].raw and command_opts[2].raw and command_opts[3].raw, "raw protocols")

  local renamed = result.status_map["/repo/new\tname.lua"]
  local normal = result.status_map["/repo/normal.lua"]
  local deleted = result.status_map["/repo/deleted.lua"]
  t.assert_true(renamed ~= nil and renamed.staged.R == true, "rename status")
  t.assert_eq("old\tname.lua", renamed.staged_prev_relative, "rename source")
  t.assert_eq("aaaaaaa", normal.staged_old_object_name, "staged source identity")
  t.assert_eq("bbbbbbb", normal.staged_new_object_name, "staged target identity")
  t.assert_eq("aaaaaaa", renamed.staged_old_object_name, "rename source identity")
  t.assert_eq("bbbbbbb", renamed.staged_new_object_name, "rename target identity")
  t.assert_true(deleted.unstaged.D == true, "unstaged deletion")
  t.assert_eq("aaaaaaa", deleted.unstaged_old_object_name, "unstaged index identity")
  t.assert_nil(deleted.unstaged_new_object_name, "worktree zero identity omitted")
  t.assert_true(result.status_map["/repo/fresh\nfile.lua"].unstaged["?"] == true, "untracked file")
  t.assert_eq(3, result.numstats.staged["normal.lua"].insertions, "normal insertions")
  t.assert_eq(1, result.numstats.staged["normal.lua"].deletions, "normal deletions")
  t.assert_eq(4, result.numstats.staged["new\tname.lua"].insertions, "rename insertions")
  t.assert_eq(2, result.numstats.staged["new\tname.lua"].deletions, "rename deletions")
  t.assert_nil(result.numstats.staged["binary.dat"], "binary stats remain unknown")
  t.assert_eq(5, result.numstats.unstaged["deleted.lua"].deletions, "unstaged deletions")
end)

t:test("collect: NUL protocol preserves special paths and rename destinations", function()
  commands = {}
  command_opts = {}
  responses = {
    {
      code = 0,
      lines = {
        ":000000 100644 0000000 aaaaaaa A\0back\\slash.lua\0"
          .. ":000000 100644 0000000 bbbbbbb A\0cr\r\nlf.lua\0"
          .. ":100644 100644 ccccccc ddddddd R100\0old\tname.lua\0new\tname.lua\0",
      },
    },
    { code = 0, lines = {} },
    { code = 0, lines = { "untracked\nname.lua\0untracked\\name.lua\0" } },
  }

  local result = status.collect(nil):get_result()
  local backslash = result.status_map["/repo/back\\slash.lua"]
  local renamed = result.status_map["/repo/new\tname.lua"]
  local crlf = result.status_map["/repo/cr\r\nlf.lua"]
  local untracked = result.status_map["/repo/untracked\nname.lua"]
  local untracked_backslash = result.status_map["/repo/untracked\\name.lua"]

  t.assert_true(backslash ~= nil, "literal tracked backslash path")
  t.assert_eq("back\\slash.lua", backslash.relative, "tracked backslash relative path")
  t.assert_true(renamed ~= nil, "literal rename destination")
  t.assert_true(renamed.staged.R == true, "rename status")
  t.assert_eq("new\tname.lua", renamed.relative, "rename relative path")
  t.assert_eq("old\tname.lua", renamed.staged_prev_relative, "rename source path")
  t.assert_true(crlf ~= nil, "literal CRLF path")
  t.assert_true(untracked ~= nil, "literal untracked path")
  t.assert_true(untracked.unstaged["?"] == true, "untracked status")
  t.assert_true(untracked_backslash ~= nil, "literal untracked backslash path")
end)

t:test("collect: staged query failure rejects instead of returning a partial snapshot", function()
  commands = {}
  command_opts = {}
  responses = {
    { code = 128, lines = {}, stderr = "fatal: corrupt index\n" },
    { code = 0, lines = { "M\0worktree.lua\0" }, stderr = "" },
    { code = 0, lines = { "untracked.lua\0" }, stderr = "" },
  }

  local future = status.collect(nil)

  t.assert_nil(future:get_result(), "partial snapshot rejected")
  t.assert_true(
    assert(future:get_error()):find("staged diff failed (exit 128): fatal: corrupt index", 1, true) ~= nil,
    "actionable staged error"
  )
end)

t:test("collect: untracked query failure rejects the otherwise complete snapshot", function()
  commands = {}
  command_opts = {}
  responses = {
    { code = 0, lines = { "M\0staged.lua\0" }, stderr = "" },
    { code = 0, lines = { "M\0worktree.lua\0" }, stderr = "" },
    { code = 1, lines = {}, stderr = "fatal: ls-files failed\n" },
  }

  local future = status.collect(nil)

  t.assert_nil(future:get_result(), "incomplete snapshot rejected")
  t.assert_true(
    assert(future:get_error()):find("untracked files failed (exit 1): fatal: ls-files failed", 1, true) ~= nil,
    "actionable untracked error"
  )
end)

t:test("collect: real Git snapshot keeps staged, unstaged, rename, and numstat aligned", function()
  local repo = vim.fn.tempname() ---@type string
  vim.fn.mkdir(repo, "p")

  ---@param ... string
  ---@return vim.SystemCompleted
  local function git(...)
    return vim.system({ "git", "-C", repo, ... }, { text = true }):wait()
  end

  local ok, err = xpcall(function()
    t.assert_eq(0, git("init", "-q").code, "git init")
    vim.fn.writefile({ "old one", "old two" }, repo .. "/old.txt")
    vim.fn.writefile({ "base" }, repo .. "/mixed.txt")
    t.assert_eq(0, git("add", "--", "old.txt", "mixed.txt").code, "initial add")
    t.assert_eq(
      0,
      git("-c", "user.name=Test", "-c", "user.email=test@example.com", "commit", "-qm", "base").code,
      "initial commit"
    )

    t.assert_eq(0, git("mv", "old.txt", "new.txt").code, "stage rename")
    vim.fn.writefile({ "staged" }, repo .. "/mixed.txt", "a")
    t.assert_eq(0, git("add", "--", "new.txt", "mixed.txt").code, "stage changes")
    vim.fn.writefile({ "unstaged" }, repo .. "/mixed.txt", "a")
    vim.fn.writefile({ "fresh" }, repo .. "/fresh.txt")

    t:patch_table(dot.path, "workspace", function()
      return repo
    end)
    t:patch_table(stl.git.exec, "exec", exec_real_git)

    local head_rename_object = vim.trim(git("rev-parse", "HEAD:old.txt").stdout or "") ---@type string
    local index_rename_object = vim.trim(git("rev-parse", ":new.txt").stdout or "") ---@type string
    local head_mixed_object = vim.trim(git("rev-parse", "HEAD:mixed.txt").stdout or "") ---@type string
    local index_mixed_object = vim.trim(git("rev-parse", ":mixed.txt").stdout or "") ---@type string

    local identity_result = status.collect(nil):get_result()
    local identity_renamed = identity_result.status_map[repo .. "/new.txt"]
    local identity_mixed = identity_result.status_map[repo .. "/mixed.txt"]
    t.assert_eq(head_rename_object, identity_renamed.staged_old_object_name, "default rename source identity")
    t.assert_eq(index_rename_object, identity_renamed.staged_new_object_name, "default rename target identity")
    t.assert_eq(index_mixed_object, identity_mixed.unstaged_old_object_name, "default index identity")

    local result = status.collect({ include_numstat = true }):get_result()
    local renamed = result.status_map[repo .. "/new.txt"]
    local mixed = result.status_map[repo .. "/mixed.txt"]

    t.assert_true(renamed ~= nil and renamed.staged.R == true, "real rename status")
    t.assert_eq("old.txt", renamed.staged_prev_relative, "real rename source")
    t.assert_eq(head_rename_object, renamed.staged_old_object_name, "real rename source identity")
    t.assert_eq(index_rename_object, renamed.staged_new_object_name, "real rename target identity")
    t.assert_true(mixed.staged.M == true and mixed.unstaged.M == true, "real mixed status")
    t.assert_eq(head_mixed_object, mixed.staged_old_object_name, "real staged source identity")
    t.assert_eq(index_mixed_object, mixed.staged_new_object_name, "real staged target identity")
    t.assert_eq(index_mixed_object, mixed.unstaged_old_object_name, "real unstaged index identity")
    t.assert_nil(mixed.unstaged_new_object_name, "real worktree identity omitted")
    t.assert_true(result.status_map[repo .. "/fresh.txt"].unstaged["?"] == true, "real untracked status")
    t.assert_eq(1, result.numstats.staged["mixed.txt"].insertions, "real staged insertions")
    t.assert_eq(1, result.numstats.unstaged["mixed.txt"].insertions, "real unstaged insertions")
  end, debug.traceback)

  vim.fn.delete(repo, "rf")
  if not ok then
    error(err)
  end
end)

t:test("collect: real Git numstat snapshot supports an unborn HEAD", function()
  local repo = vim.fn.tempname() ---@type string
  vim.fn.mkdir(repo, "p")

  local ok, err = xpcall(function()
    t.assert_eq(0, vim.system({ "git", "-C", repo, "init", "-q" }, { text = true }):wait().code, "git init")
    vim.fn.writefile({ "first", "second" }, repo .. "/first.txt")
    t.assert_eq(0, vim.system({ "git", "-C", repo, "add", "--", "first.txt" }, { text = true }):wait().code, "add")

    t:patch_table(dot.path, "workspace", function()
      return repo
    end)
    t:patch_table(stl.git.exec, "exec", exec_real_git)

    local index_result = vim.system({ "git", "-C", repo, "rev-parse", ":first.txt" }, { text = true }):wait()
    local index_object = vim.trim(index_result.stdout or "") ---@type string

    local identity_result = status.collect(nil):get_result()
    local identity_first = identity_result.status_map[repo .. "/first.txt"]
    t.assert_nil(identity_first.staged_old_object_name, "default unborn source identity omitted")
    t.assert_eq(index_object, identity_first.staged_new_object_name, "default unborn index identity")

    local result = status.collect({ include_numstat = true }):get_result()
    local first = result.status_map[repo .. "/first.txt"]
    t.assert_true(first.staged.A == true, "unborn staged add")
    t.assert_nil(first.staged_old_object_name, "unborn source identity omitted")
    t.assert_eq(index_object, first.staged_new_object_name, "unborn index identity")
    t.assert_eq(2, result.numstats.staged["first.txt"].insertions, "unborn insertions")
    t.assert_eq(0, result.numstats.staged["first.txt"].deletions, "unborn deletions")
  end, debug.traceback)

  vim.fn.delete(repo, "rf")
  if not ok then
    error(err)
  end
end)

t:test("collect: delayed child rejection settles the outer future", function()
  commands = {}
  command_opts = {}
  local children = { RealFuture.new(), RealFuture.new(), RealFuture.new() }

  t:patch_table(stl, "async", async)
  t:patch_table(stl.c, "Future", RealFuture)
  t:patch_table(stl.git.exec, "exec", function(args, opts)
    commands[#commands + 1] = args
    command_opts[#command_opts + 1] = opts
    return children[#commands]
  end)

  local future = status.collect(nil)
  t.assert_false(future:is_done(), "collection waits for Git queries")

  children[1]:__reject__("delayed Git failure") ---@diagnostic disable-line: invisible

  t.assert_true(future:is_done(), "collection settled")
  t.assert_true(future:is_failed(), "collection rejected")
  t.assert_true(assert(future:get_error()):find("delayed Git failure", 1, true) ~= nil, "delayed rejection preserved")
end)

t:run()
