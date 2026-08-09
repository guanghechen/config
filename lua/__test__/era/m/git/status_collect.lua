---@diagnostic disable: undefined-global
--- Run with: nvim -l lua/__test__/era/m/git/status_collect.lua

local bootstrap = require("__test__.bootstrap")
local harness = require("__test__.harness")
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

t:test("collect: default staged diff does not require HEAD", function()
  commands = {}
  command_opts = {}
  responses = {}
  local result = status.collect(nil):get_result()

  t.assert_true(result ~= nil, "collection result")
  t.assert_eq("diff --staged --name-status -z --", table.concat(commands[1], " "), "staged command")
  t.assert_eq("diff --name-status -z --", table.concat(commands[2], " "), "unstaged command")
  t.assert_eq("ls-files --exclude-standard --others -z", table.concat(commands[3], " "), "untracked command")
  t.assert_true(command_opts[1].raw, "staged raw output")
  t.assert_true(command_opts[2].raw, "unstaged raw output")
  t.assert_true(command_opts[3].raw, "untracked raw output")
end)

t:test("collect: explicit base remains supported", function()
  commands = {}
  command_opts = {}
  responses = {}
  status.collect({ base = "HEAD" }):get_result()

  t.assert_eq("diff --staged --name-status -z HEAD --", table.concat(commands[1], " "), "staged command")
end)

t:test("collect: NUL protocol preserves special paths and rename destinations", function()
  commands = {}
  command_opts = {}
  responses = {
    { code = 0, lines = { "A\0back\\slash.lua\0A\0cr\r\nlf.lua\0R100\0old\tname.lua\0new\tname.lua\0" } },
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
