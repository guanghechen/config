local bootstrap = require("__test__.support.bootstrap")
local harness = require("__test__.support.harness")

local t = harness.new()
local Async = require("stl.async")
local Future = require("stl.c.future")

local reported = {} ---@type table[]
bootstrap.with_global(t, "stl", {
  async = Async,
  c = { Future = Future },
  reporter = {
    error = function(value)
      reported[#reported + 1] = value
    end,
  },
})

---@return stl.c.Future
local function later()
  return Future.new(function(resolve)
    vim.schedule(function()
      resolve(nil)
    end)
  end)
end

t:test("run_future resolves the async return value", function()
  local future = Async.run_future(function()
    return "done"
  end)

  t.assert_true(future:is_resolved(), "future")
  t.assert_eq("done", future:get_result(), "result")
end)

t:test("run_future rejects a failure after await", function()
  local future = Async.run_future(function()
    Future.new(function(resolve)
      vim.schedule(function()
        resolve(nil)
      end)
    end):await()
    error("injected post-await failure", 0)
  end)

  t.wait_until(function()
    return future:is_done()
  end, 1000, "post-await failure")

  t.assert_true(future:is_failed(), "future")
  t.assert_true(future:get_error():find("injected post-await failure", 1, true) ~= nil, "diagnostic")
end)

t:test("run reports an error that ends it, after an await as before one", function()
  reported = {}
  local reached = false
  Async.run(function()
    later():await()
    error("injected post-await failure", 0)
  end)
  Async.run(function()
    error("injected failure", 0)
  end)
  Async.run(function()
    later():await()
    Future.reject("command failed"):await()
    reached = true
  end)

  t.wait_until(function()
    return #reported == 3
  end, 1000, "the three failures")
  local messages = vim.tbl_map(function(value)
    return value.message:match("^[^\n]*")
  end, reported)
  table.sort(messages)
  t.assert_same({ "command failed", "injected failure", "injected post-await failure" }, messages, "each failure")
  t.assert_false(reached, "nothing runs after a failure")
end)

t:test("run ends quietly on a cancellation", function()
  reported = {}
  local token = require("stl.c.cancellation_token").new()
  local cancelled = Future.new({ token = token })
  Async.run(function()
    cancelled:await()
  end)
  token:cancel()
  t.assert_true(cancelled:is_cancelled(), "cancelled")
  vim.wait(20)
  t.assert_same({}, reported, "a cancelled future")
end)

t:test("run_future rejects an invalid coroutine yield", function()
  local future = Async.run_future(function()
    coroutine.yield("invalid")
  end)

  t.assert_true(future:is_failed(), "future")
  t.assert_true(future:get_error():find("expected func", 1, true) ~= nil, "diagnostic")
end)

t:run()
