---@diagnostic disable: undefined-global

local bootstrap = require("__test__.bootstrap")
local harness = require("__test__.harness")

local t = harness.new("stl.async")
local Async = require("stl.async")
local Future = require("stl.c.future")

bootstrap.with_stl(t, {
  async = Async,
  c = { Future = Future },
})

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

t:test("run_future rejects an invalid coroutine yield", function()
  local future = Async.run_future(function()
    coroutine.yield("invalid")
  end)

  t.assert_true(future:is_failed(), "future")
  t.assert_true(future:get_error():find("expected func", 1, true) ~= nil, "diagnostic")
end)

t:run()
