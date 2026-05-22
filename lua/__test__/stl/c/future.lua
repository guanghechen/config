---@diagnostic disable: undefined-global, invisible, unused-local, redundant-parameter
--- Test for stl.c.Future module
--- Run with: nvim -l lua/__test__/stl/c/future.lua

local harness = require("__test__.harness")
local Future = require("stl.c.future")
local CancellationToken = require("stl.c.cancellation_token")

local t = harness.new("stl.c.future")

----------------------------------------------------------------------------------------------------
-- Constructor tests
----------------------------------------------------------------------------------------------------

t:test("new: creates pending future", function()
  local future = Future.new()
  t.assert_false(future:is_done(), "should not be done")
  t.assert_false(future:is_resolved(), "should not be resolved")
  t.assert_false(future:is_cancelled(), "should not be cancelled")
  t.assert_false(future:is_failed(), "should not be failed")
end)

t:test("new: accepts token in props", function()
  local token = CancellationToken.new()
  local future = Future.new({ token = token })
  t.assert_false(future:is_done(), "should be pending")
end)

t:test("new: works with nil props", function()
  local future = Future.new(nil)
  t.assert_false(future:is_done(), "should create valid future")
end)

----------------------------------------------------------------------------------------------------
-- Executor pattern tests (ES Promise-compatible)
----------------------------------------------------------------------------------------------------

t:test("new: executor pattern resolves synchronously", function()
  local future = Future.new(function(resolve, reject)
    resolve("sync value")
  end)
  t.assert_true(future:is_done(), "should be done")
  t.assert_true(future:is_resolved(), "should be resolved")
  t.assert_eq("sync value", future:get_result(), "should have value")
end)

t:test("new: executor pattern rejects synchronously", function()
  local future = Future.new(function(resolve, reject)
    reject("sync error")
  end)
  t.assert_true(future:is_done(), "should be done")
  t.assert_true(future:is_failed(), "should be failed")
  t.assert_eq("sync error", future:get_error(), "should have error")
end)

t:test("new: executor can store resolve/reject for async use", function()
  local stored_resolve ---@type fun(result: any): nil
  local future = Future.new(function(resolve, reject)
    stored_resolve = resolve
  end)
  t.assert_false(future:is_done(), "should be pending")

  stored_resolve("async value")
  t.assert_true(future:is_resolved(), "should be resolved")
  t.assert_eq("async value", future:get_result(), "should have value")
end)

t:test("new: executor errors are caught and reject the future", function()
  local future = Future.new(function(resolve, _reject)
    error("executor threw", 0)
  end)
  t.assert_true(future:is_failed(), "should be failed")
  local err = future:get_error()
  t.assert_true(err ~= nil and string.find(err, "executor threw") ~= nil, "should have error message")
end)

t:test("new: second resolve call is ignored", function()
  local future = Future.new(function(resolve, reject)
    resolve("first")
    resolve("second")
  end)
  t.assert_eq("first", future:get_result(), "should keep first value")
end)

t:test("new: reject after resolve is ignored", function()
  local future = Future.new(function(resolve, reject)
    resolve("value")
    reject("error")
  end)
  t.assert_true(future:is_resolved(), "should be resolved")
  t.assert_nil(future:get_error(), "should have no error")
end)

----------------------------------------------------------------------------------------------------
-- Static constructors
----------------------------------------------------------------------------------------------------

t:test("resolve: creates resolved future", function()
  local future = Future.resolve("value")
  t.assert_true(future:is_done(), "should be done")
  t.assert_true(future:is_resolved(), "should be resolved")
  t.assert_eq("value", future:get_result(), "should have result")
end)

t:test("reject: creates rejected future", function()
  local future = Future.reject("error message")
  t.assert_true(future:is_done(), "should be done")
  t.assert_true(future:is_failed(), "should be failed")
  t.assert_eq("error message", future:get_error(), "should have error")
end)

----------------------------------------------------------------------------------------------------
-- State checks
----------------------------------------------------------------------------------------------------

t:test("is_done: false when pending", function()
  local future = Future.new()
  t.assert_false(future:is_done())
end)

t:test("is_done: true when resolved", function()
  local future = Future.new()
  future:__resolve__("value")
  t.assert_true(future:is_done())
end)

t:test("is_done: true when rejected", function()
  local future = Future.new()
  future:__reject__("error")
  t.assert_true(future:is_done())
end)

t:test("is_done: true when cancelled", function()
  local token = CancellationToken.new()
  local future = Future.new({ token = token })
  token:cancel()
  t.assert_true(future:is_done())
end)

t:test("is_resolved: true only when resolved", function()
  local future = Future.new()
  future:__resolve__("value")
  t.assert_true(future:is_resolved())
  t.assert_false(future:is_failed())
  t.assert_false(future:is_cancelled())
end)

t:test("is_cancelled: true only when cancelled", function()
  local token = CancellationToken.new()
  local future = Future.new({ token = token })
  token:cancel()
  t.assert_true(future:is_cancelled())
  t.assert_true(future:is_failed()) -- cancelled is also failed
  t.assert_false(future:is_resolved())
end)

t:test("is_failed: true when rejected or cancelled", function()
  local future1 = Future.new()
  future1:__reject__("error")
  t.assert_true(future1:is_failed())

  local token = CancellationToken.new()
  local future2 = Future.new({ token = token })
  token:cancel()
  t.assert_true(future2:is_failed())
end)

----------------------------------------------------------------------------------------------------
-- get_result / get_error
----------------------------------------------------------------------------------------------------

t:test("get_result: returns nil when pending", function()
  local future = Future.new()
  t.assert_nil(future:get_result())
end)

t:test("get_result: returns value when resolved", function()
  local future = Future.new()
  future:__resolve__({ key = "value" })
  local result = future:get_result()
  t.assert_eq("value", result.key)
end)

t:test("get_error: returns nil when pending", function()
  local future = Future.new()
  t.assert_nil(future:get_error())
end)

t:test("get_error: returns error when rejected", function()
  local future = Future.new()
  future:__reject__("my error")
  t.assert_eq("my error", future:get_error())
end)

t:test("get_error: returns error when cancelled", function()
  local token = CancellationToken.new()
  local future = Future.new({ token = token })
  token:cancel()
  local err = future:get_error()
  t.assert_true(err ~= nil and string.find(err, "cancelled") ~= nil)
end)

----------------------------------------------------------------------------------------------------
-- finally tests
----------------------------------------------------------------------------------------------------

t:test("finally: called immediately if already resolved", function()
  local future = Future.resolve("value")
  local called = false
  local received_ok = nil
  local received_result = nil

  future:finally(function(ok, result)
    called = true
    received_ok = ok
    received_result = result
  end)

  t.assert_true(called, "should be called immediately")
  t.assert_true(received_ok, "ok should be true")
  t.assert_eq("value", received_result, "result should be value")
end)

t:test("finally: called immediately if already rejected", function()
  local future = Future.reject("error")
  local called = false
  local received_ok = nil
  local received_result = nil

  future:finally(function(ok, result)
    called = true
    received_ok = ok
    received_result = result
  end)

  t.assert_true(called, "should be called immediately")
  t.assert_false(received_ok, "ok should be false")
  t.assert_eq("error", received_result, "result should be error")
end)

t:test("finally: queued when pending, called on resolve", function()
  local future = Future.new()
  local called = false
  local received_ok = nil
  local received_result = nil

  future:finally(function(ok, result)
    called = true
    received_ok = ok
    received_result = result
  end)

  t.assert_false(called, "should not be called yet")

  future:__resolve__("done")

  t.assert_true(called, "should be called after resolve")
  t.assert_true(received_ok, "ok should be true")
  t.assert_eq("done", received_result, "result should be value")
end)

t:test("finally: queued when pending, called on reject", function()
  local future = Future.new()
  local called = false
  local received_ok = nil

  future:finally(function(ok, result)
    called = true
    received_ok = ok
  end)

  future:__reject__("failed")

  t.assert_true(called, "should be called after reject")
  t.assert_false(received_ok, "ok should be false")
end)

t:test("finally: multiple listeners all called", function()
  local future = Future.new()
  local count = 0

  future:finally(function()
    count = count + 1
  end)
  future:finally(function()
    count = count + 1
  end)
  future:finally(function()
    count = count + 1
  end)

  future:__resolve__("value")
  t.assert_eq(3, count, "all listeners called")
end)

t:test("finally: handles callback errors gracefully", function()
  local future = Future.new()
  local second_called = false

  future:finally(function()
    error("intentional error")
  end)
  future:finally(function()
    second_called = true
  end)

  future:__resolve__("value")
  t.assert_true(second_called, "second listener should still be called")
end)

----------------------------------------------------------------------------------------------------
-- __resolve__ tests
----------------------------------------------------------------------------------------------------

t:test("__resolve__: transitions state to resolved", function()
  local future = Future.new()
  future:__resolve__("value")
  t.assert_eq("value", future:get_result())
  t.assert_true(future:is_resolved())
end)

t:test("__resolve__: is idempotent (second call ignored)", function()
  local future = Future.new()
  future:__resolve__("first")
  future:__resolve__("second")
  t.assert_eq("first", future:get_result(), "should keep first value")
end)

t:test("__resolve__: ignored if already rejected", function()
  local future = Future.new()
  future:__reject__("error")
  future:__resolve__("value")
  t.assert_true(future:is_failed(), "should still be failed")
  t.assert_nil(future:get_result(), "should have no result")
end)

----------------------------------------------------------------------------------------------------
-- __reject__ tests
----------------------------------------------------------------------------------------------------

t:test("__reject__: transitions state to rejected", function()
  local future = Future.new()
  future:__reject__("error")
  t.assert_eq("error", future:get_error())
  t.assert_true(future:is_failed())
end)

t:test("__reject__: is idempotent (second call ignored)", function()
  local future = Future.new()
  future:__reject__("first error")
  future:__reject__("second error")
  t.assert_eq("first error", future:get_error(), "should keep first error")
end)

t:test("__reject__: ignored if already resolved", function()
  local future = Future.new()
  future:__resolve__("value")
  future:__reject__("error")
  t.assert_true(future:is_resolved(), "should still be resolved")
  t.assert_nil(future:get_error(), "should have no error")
end)

----------------------------------------------------------------------------------------------------
-- Cancellation tests
----------------------------------------------------------------------------------------------------

t:test("cancel: token cancellation cancels future", function()
  local token = CancellationToken.new()
  local future = Future.new({ token = token })

  t.assert_false(future:is_cancelled(), "should not be cancelled yet")

  token:cancel()

  t.assert_true(future:is_cancelled(), "should be cancelled")
  t.assert_true(future:is_done(), "should be done")
end)

t:test("cancel: finally called on cancellation", function()
  local token = CancellationToken.new()
  local future = Future.new({ token = token })
  local called = false
  local received_ok = nil

  future:finally(function(ok, _)
    called = true
    received_ok = ok
  end)

  token:cancel()

  t.assert_true(called, "finally should be called")
  t.assert_false(received_ok, "ok should be false for cancellation")
end)

t:test("cancel: resolve after cancel is ignored", function()
  local token = CancellationToken.new()
  local future = Future.new({ token = token })

  token:cancel()
  future:__resolve__("value")

  t.assert_true(future:is_cancelled(), "should remain cancelled")
  t.assert_nil(future:get_result(), "should have no result")
end)

----------------------------------------------------------------------------------------------------
-- IDisposable interface tests
----------------------------------------------------------------------------------------------------

t:test("isdisposed: false when pending", function()
  local future = Future.new()
  t.assert_false(future:isdisposed())
end)

t:test("isdisposed: true when done", function()
  local future = Future.new()
  future:__resolve__("value")
  t.assert_true(future:isdisposed())
end)

t:test("dispose: cancels via token", function()
  local token = CancellationToken.new()
  local future = Future.new({ token = token })

  local result = future:dispose()

  t.assert_true(result, "dispose should return true")
  t.assert_true(future:is_cancelled(), "should be cancelled")
end)

t:test("dispose: returns false without token", function()
  local future = Future.new()
  local result = future:dispose()
  t.assert_false(result, "dispose should return false without token")
end)

----------------------------------------------------------------------------------------------------
-- then_ tests
----------------------------------------------------------------------------------------------------

t:test("then_: chains resolved future", function()
  local future = Future.resolve(10)
  local chained = future:then_(function(result)
    return result * 2
  end)
  t.assert_true(chained:is_resolved())
  t.assert_eq(20, chained:get_result())
end)

t:test("then_: chains rejected future with on_rejected", function()
  local future = Future.reject("error")
  local chained = future:then_(nil, function(err)
    return "recovered: " .. err
  end)
  t.assert_true(chained:is_resolved())
  t.assert_eq("recovered: error", chained:get_result())
end)

t:test("then_: propagates rejection without on_rejected", function()
  local future = Future.reject("error")
  local chained = future:then_(function(result)
    return result * 2
  end)
  t.assert_true(chained:is_failed())
  t.assert_eq("error", chained:get_error())
end)

t:test("then_: propagates resolution without on_resolved", function()
  local future = Future.resolve("value")
  local chained = future:then_(nil, function(err)
    return "recovered"
  end)
  t.assert_true(chained:is_resolved())
  t.assert_eq("value", chained:get_result())
end)

t:test("then_: handles callback errors", function()
  local future = Future.resolve("value")
  local chained = future:then_(function(_)
    error("callback error", 0)
  end)
  t.assert_true(chained:is_failed())
  local err = chained:get_error()
  t.assert_true(err ~= nil and string.find(err, "callback error") ~= nil)
end)

t:test("then_: waits for returned future", function()
  local inner, resolver = Future.new_with_resolver()
  local future = Future.resolve("value")
  local chained = future:then_(function(_)
    return inner
  end)

  t.assert_false(chained:is_done(), "should wait for inner future")

  resolver("inner result")
  t.assert_true(chained:is_resolved())
  t.assert_eq("inner result", chained:get_result())
end)

t:test("then_: chained calls work correctly", function()
  local future = Future.resolve(1)
  local chained = future
    :then_(function(x)
      return x + 1
    end)
    :then_(function(x)
      return x * 2
    end)
    :then_(function(x)
      return x + 10
    end)

  t.assert_true(chained:is_resolved())
  t.assert_eq(14, chained:get_result()) -- ((1+1)*2)+10 = 14
end)

t:test("then_: pending future chains correctly", function()
  local future, resolver = Future.new_with_resolver()
  local chained = future:then_(function(result)
    return result .. "!"
  end)

  t.assert_false(chained:is_done(), "should be pending")

  resolver("hello")
  t.assert_true(chained:is_resolved())
  t.assert_eq("hello!", chained:get_result())
end)

----------------------------------------------------------------------------------------------------
-- catch tests
----------------------------------------------------------------------------------------------------

t:test("catch: catches rejected future", function()
  local future = Future.reject("error")
  local caught = future:catch(function(err)
    return "caught: " .. err
  end)
  t.assert_true(caught:is_resolved())
  t.assert_eq("caught: error", caught:get_result())
end)

t:test("catch: passes through resolved future", function()
  local future = Future.resolve("value")
  local caught = future:catch(function(err)
    return "caught"
  end)
  t.assert_true(caught:is_resolved())
  t.assert_eq("value", caught:get_result())
end)

t:test("catch: catches cancelled future", function()
  local token = CancellationToken.new()
  local future = Future.new({ token = token })
  local caught = future:catch(function(err)
    return "caught cancel"
  end)

  token:cancel()
  t.assert_true(caught:is_resolved())
  t.assert_eq("caught cancel", caught:get_result())
end)

----------------------------------------------------------------------------------------------------
-- map tests
----------------------------------------------------------------------------------------------------

t:test("map: transforms resolved value", function()
  local future = Future.resolve(5)
  local mapped = future:map(function(x)
    return x * 3
  end)
  t.assert_true(mapped:is_resolved())
  t.assert_eq(15, mapped:get_result())
end)

t:test("map: propagates rejection", function()
  local future = Future.reject("error")
  local mapped = future:map(function(x)
    return x * 3
  end)
  t.assert_true(mapped:is_failed())
  t.assert_eq("error", mapped:get_error())
end)

t:test("map: handles callback errors", function()
  local future = Future.resolve(5)
  local mapped = future:map(function(_)
    error("map error", 0)
  end)
  t.assert_true(mapped:is_failed())
  local err = mapped:get_error()
  t.assert_true(err ~= nil and string.find(err, "map error") ~= nil)
end)

----------------------------------------------------------------------------------------------------
-- Future.all tests
----------------------------------------------------------------------------------------------------

t:test("all: resolves with empty array for empty input", function()
  local future = Future.all({})
  t.assert_true(future:is_resolved())
  local result = future:get_result()
  t.assert_eq(0, #result)
end)

t:test("all: resolves when all futures resolve", function()
  local f1 = Future.resolve(1)
  local f2 = Future.resolve(2)
  local f3 = Future.resolve(3)

  local future = Future.all({ f1, f2, f3 })
  t.assert_true(future:is_resolved())

  local result = future:get_result()
  t.assert_eq(1, result[1])
  t.assert_eq(2, result[2])
  t.assert_eq(3, result[3])
end)

t:test("all: rejects immediately on first rejection", function()
  local f1 = Future.resolve(1)
  local f2 = Future.reject("error2")
  local f3 = Future.resolve(3)

  local future = Future.all({ f1, f2, f3 })
  t.assert_true(future:is_failed())
  t.assert_eq("error2", future:get_error())
end)

t:test("all: preserves order of results", function()
  local f1, r1 = Future.new_with_resolver()
  local f2, r2 = Future.new_with_resolver()
  local f3, r3 = Future.new_with_resolver()

  local future = Future.all({ f1, f2, f3 })

  r3("third")
  r1("first")
  r2("second")

  t.assert_true(future:is_resolved())
  local result = future:get_result()
  t.assert_eq("first", result[1])
  t.assert_eq("second", result[2])
  t.assert_eq("third", result[3])
end)

t:test("all: supports token cancellation", function()
  local token = CancellationToken.new()
  local f1 = Future.resolve(1)
  local f2 = Future.new()

  local future = Future.all({ f1, f2 }, token)

  t.assert_false(future:is_done())

  token:cancel()
  t.assert_true(future:is_cancelled())
end)

t:test("all: ignores late results after rejection", function()
  local f1, r1 = Future.new_with_resolver()
  local f2 = Future.reject("early error")

  local future = Future.all({ f1, f2 })

  t.assert_true(future:is_failed())
  t.assert_eq("early error", future:get_error())

  r1("late value")
  t.assert_eq("early error", future:get_error())
end)

----------------------------------------------------------------------------------------------------
-- Future.race tests
----------------------------------------------------------------------------------------------------

t:test("race: returns pending for empty input", function()
  local future = Future.race({})
  t.assert_false(future:is_done())
end)

t:test("race: resolves with first resolved future", function()
  local f1, r1 = Future.new_with_resolver()
  local f2 = Future.resolve("winner")
  local f3 = Future.new()

  local future = Future.race({ f1, f2, f3 })
  t.assert_true(future:is_resolved())
  t.assert_eq("winner", future:get_result())
end)

t:test("race: rejects with first rejected future", function()
  local f1 = Future.new()
  local f2 = Future.reject("loser")
  local f3 = Future.new()

  local future = Future.race({ f1, f2, f3 })
  t.assert_true(future:is_failed())
  t.assert_eq("loser", future:get_error())
end)

t:test("race: ignores late results", function()
  local f1, r1 = Future.new_with_resolver()
  local f2, r2 = Future.new_with_resolver()

  local future = Future.race({ f1, f2 })

  r1("first")
  t.assert_true(future:is_resolved())
  t.assert_eq("first", future:get_result())

  r2("second")
  t.assert_eq("first", future:get_result())
end)

t:test("race: supports token cancellation", function()
  local token = CancellationToken.new()
  local f1 = Future.new()
  local f2 = Future.new()

  local future = Future.race({ f1, f2 }, token)

  t.assert_false(future:is_done())

  token:cancel()
  t.assert_true(future:is_cancelled())
end)

----------------------------------------------------------------------------------------------------
-- Future.any tests
----------------------------------------------------------------------------------------------------

t:test("any: rejects for empty input", function()
  local future = Future.any({})
  t.assert_true(future:is_failed())
  t.assert_eq("All futures rejected", future:get_error())
end)

t:test("any: resolves with first resolved future", function()
  local f1 = Future.reject("error1")
  local f2 = Future.resolve("winner")
  local f3 = Future.reject("error3")

  local future = Future.any({ f1, f2, f3 })
  t.assert_true(future:is_resolved())
  t.assert_eq("winner", future:get_result())
end)

t:test("any: rejects when all futures reject", function()
  local f1 = Future.reject("error1")
  local f2 = Future.reject("error2")
  local f3 = Future.reject("error3")

  local future = Future.any({ f1, f2, f3 })
  t.assert_true(future:is_failed())
  t.assert_eq("All futures rejected", future:get_error())
end)

t:test("any: ignores rejections before first resolution", function()
  local f1, r1 = Future.new_with_resolver()
  local f2 = Future.reject("error")
  local f3, r3 = Future.new_with_resolver()

  local future = Future.any({ f1, f2, f3 })

  t.assert_false(future:is_done(), "should wait for potential success")

  r3("success")
  t.assert_true(future:is_resolved())
  t.assert_eq("success", future:get_result())
end)

t:test("any: supports token cancellation", function()
  local token = CancellationToken.new()
  local f1 = Future.reject("error")
  local f2 = Future.new()

  local future = Future.any({ f1, f2 }, token)

  t.assert_false(future:is_done())

  token:cancel()
  t.assert_true(future:is_cancelled())
end)

t:test("any: ignores late results after first success", function()
  local f1, r1 = Future.new_with_resolver()
  local f2, r2 = Future.new_with_resolver()

  local future = Future.any({ f1, f2 })

  r1("first")
  t.assert_true(future:is_resolved())
  t.assert_eq("first", future:get_result())

  r2("second")
  t.assert_eq("first", future:get_result())
end)

----------------------------------------------------------------------------------------------------
-- Future.allSettled tests
----------------------------------------------------------------------------------------------------

t:test("allSettled: resolves with empty array for empty input", function()
  local future = Future.allSettled({})
  t.assert_true(future:is_resolved())
  local result = future:get_result()
  t.assert_eq(0, #result)
end)

t:test("allSettled: resolves with all results when all futures resolve", function()
  local f1 = Future.resolve(1)
  local f2 = Future.resolve(2)
  local f3 = Future.resolve(3)

  local future = Future.allSettled({ f1, f2, f3 })
  t.assert_true(future:is_resolved())

  local result = future:get_result()
  t.assert_eq(3, #result)
  t.assert_eq("fulfilled", result[1].status)
  t.assert_eq(1, result[1].value)
  t.assert_eq("fulfilled", result[2].status)
  t.assert_eq(2, result[2].value)
  t.assert_eq("fulfilled", result[3].status)
  t.assert_eq(3, result[3].value)
end)

t:test("allSettled: resolves with all results when some futures reject", function()
  local f1 = Future.resolve("ok")
  local f2 = Future.reject("error2")
  local f3 = Future.resolve("also ok")

  local future = Future.allSettled({ f1, f2, f3 })
  t.assert_true(future:is_resolved(), "should always resolve")

  local result = future:get_result()
  t.assert_eq(3, #result)
  t.assert_eq("fulfilled", result[1].status)
  t.assert_eq("ok", result[1].value)
  t.assert_eq("rejected", result[2].status)
  t.assert_eq("error2", result[2].reason)
  t.assert_eq("fulfilled", result[3].status)
  t.assert_eq("also ok", result[3].value)
end)

t:test("allSettled: resolves with all results when all futures reject", function()
  local f1 = Future.reject("error1")
  local f2 = Future.reject("error2")

  local future = Future.allSettled({ f1, f2 })
  t.assert_true(future:is_resolved(), "should always resolve")

  local result = future:get_result()
  t.assert_eq(2, #result)
  t.assert_eq("rejected", result[1].status)
  t.assert_eq("error1", result[1].reason)
  t.assert_eq("rejected", result[2].status)
  t.assert_eq("error2", result[2].reason)
end)

t:test("allSettled: preserves order of results", function()
  local f1, r1 = Future.new_with_resolver()
  local f2, r2 = Future.new_with_resolver()
  local f3, r3 = Future.new_with_resolver()

  local future = Future.allSettled({ f1, f2, f3 })

  r3("third")
  r1("first")
  r2("second")

  t.assert_true(future:is_resolved())
  local result = future:get_result()
  t.assert_eq("first", result[1].value)
  t.assert_eq("second", result[2].value)
  t.assert_eq("third", result[3].value)
end)

t:test("allSettled: supports token cancellation", function()
  local token = CancellationToken.new()
  local f1 = Future.resolve(1)
  local f2 = Future.new()

  local future = Future.allSettled({ f1, f2 }, token)

  t.assert_false(future:is_done())

  token:cancel()
  t.assert_true(future:is_cancelled())
end)

t:run()
