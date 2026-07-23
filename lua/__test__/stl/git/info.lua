---@diagnostic disable: undefined-global
--- Test for stl.git.info module
--- Run with: nvim -l lua/__test__/stl/git/info.lua

local bootstrap = require("__test__.bootstrap")
local CancellationToken = require("stl.c.cancellation_token")
local Future = require("stl.c.future")
local harness = require("__test__.harness")

local t = harness.new("stl.git.info")

bootstrap.with_runtime(t, {
  stl = {
    c = { Future = Future },
    env = { PATH_SEP = "/" },
  },
  yoz = {
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
