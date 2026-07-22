---@diagnostic disable: undefined-global
--- Test for era.m.git.repo module
--- Run with: nvim -l lua/__test__/era/m/git/repo.lua

local bootstrap = require("__test__.bootstrap")
local CancellationToken = require("stl.c.cancellation_token")
local Future = require("stl.c.future")
local harness = require("__test__.harness")

local t = harness.new("era.m.git.repo")

---@class era.m.git.repo.test.IRequest
---@field resolve                      fun(result: table|nil): nil
---@field token                        stl.c.CancellationToken|nil

local requests = {} ---@type era.m.git.repo.test.IRequest[]
local abbrev_calls = 0 ---@type integer

bootstrap.with_stl(t, {
  async = require("stl.async"),
  c = { Future = Future },
  git = {
    info = {
      get_abbrev_head = function()
        abbrev_calls = abbrev_calls + 1
        return Future.resolve({ abbrev_head = "main", detached = false })
      end,
      get_toplevel = function(_, token)
        local future, resolve = Future.new_with_resolver()
        requests[#requests + 1] = { resolve = resolve, token = token }
        return future
      end,
    },
  },
})

local Repo = require("era.m.git.repo")

local function reset()
  requests = {}
  abbrev_calls = 0
end

local function resolve_repo(index)
  requests[index].resolve({ gitdir = "/repo/.git", toplevel = "/repo" })
end

t:test("concurrent unowned creates share one future", function()
  reset()

  local first = Repo.create("/repo")
  local second = Repo.create("/repo")

  t.assert_eq(first, second, "shared future")
  t.assert_eq(1, #requests, "toplevel queries")

  resolve_repo(1)

  t.assert_true(first:is_resolved(), "shared future resolved")
  t.assert_eq(1, abbrev_calls, "abbrev queries")
end)

t:test("successful create releases the in-flight entry", function()
  reset()

  local first = Repo.create("/repo")
  resolve_repo(1)
  local second = Repo.create("/repo")

  t.assert_true(first ~= second, "new future")
  t.assert_eq(2, #requests, "new toplevel query")
  requests[2].resolve(nil)
end)

t:test("failed create releases the in-flight entry", function()
  reset()

  local first = Repo.create("/repo")
  requests[1].resolve(nil)
  local second = Repo.create("/repo")

  t.assert_true(first ~= second, "new future after failure")
  t.assert_eq(2, #requests, "retried toplevel query")
  requests[2].resolve(nil)
end)

t:test("token-owned creates remain isolated", function()
  reset()

  local token = CancellationToken.new()
  local first = Repo.create("/repo", token)
  local second = Repo.create("/repo", token)

  t.assert_true(first ~= second, "independent futures")
  t.assert_eq(2, #requests, "independent toplevel queries")
  requests[1].resolve(nil)
  requests[2].resolve(nil)
end)

t:run()
