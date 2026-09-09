--- Run with: nvim -l __test__/run.lua __test__/specs/era/m/git/index_spec.lua
---@diagnostic disable: undefined-global

local bootstrap = require("__test__.support.bootstrap")
local harness = require("__test__.support.harness")

local t = harness.new("era.m.git.index")
bootstrap.with_stl_c(t)

local index = require("era.m.git.index")

t:test("same-worktree mutations run in FIFO order", function()
  local started = {} ---@type string[]
  local release = nil ---@type (fun(result: string): nil)|nil

  local first = index.run("/repo", function(resolve)
    started[#started + 1] = "first"
    release = resolve
  end)
  local second = index.run("/repo", function(resolve)
    started[#started + 1] = "second"
    resolve("second-result")
  end)

  t.assert_eq("first", table.concat(started, ","), "second task waits")
  assert(release)("first-result")
  t.assert_eq("first,second", table.concat(started, ","), "FIFO order")
  t.assert_eq("first-result", first:get_result(), "first result")
  t.assert_eq("second-result", second:get_result(), "second result")
end)

t:test("different worktrees can mutate independently", function()
  local started = {} ---@type string[]
  local release = nil ---@type (fun(result: boolean): nil)|nil

  index.run("/repo-a", function(resolve)
    started[#started + 1] = "a"
    release = resolve
  end)
  index.run("/repo-b", function(resolve)
    started[#started + 1] = "b"
    resolve(true)
  end)

  t.assert_eq("a,b", table.concat(started, ","), "independent queues")
  assert(release)(true)
end)

t:test("task exceptions reject and release the queue", function()
  local failed = index.run("/repo", function()
    error("injected failure")
  end)
  local recovered = index.run("/repo", function(resolve)
    resolve("recovered")
  end)

  t.assert_true(failed:is_failed(), "failed task rejected")
  t.assert_eq("recovered", recovered:get_result(), "next task started")
end)

t:run()
