---@diagnostic disable: undefined-global, invisible, unused-local, redundant-parameter
--- Test for stl.c.Future module
--- Run with: nvim -l lua/__test__/stl/c/future_test.lua

local Future = require("stl.c.future")
local CancellationToken = require("stl.c.cancellation_token")

local passed = 0
local failed = 0

---@param name                          string
---@param fn                            fun()
local function test(name, fn)
  local ok, err = pcall(fn)
  if ok then
    passed = passed + 1
    print("✓ " .. name)
  else
    failed = failed + 1
    print("✗ " .. name)
    print("  Error: " .. tostring(err))
  end
end

---@param expected                      any
---@param actual                        any
---@param msg                           ?string
local function assert_eq(expected, actual, msg)
  if expected ~= actual then
    error(string.format("%s: expected %s, got %s", msg or "assertion failed", tostring(expected), tostring(actual)))
  end
end

---@param actual                        any
---@param msg                           ?string
local function assert_true(actual, msg)
  if not actual then
    error(string.format("%s: expected true, got %s", msg or "assertion failed", tostring(actual)))
  end
end

---@param actual                        any
---@param msg                           ?string
local function assert_false(actual, msg)
  if actual then
    error(string.format("%s: expected false, got %s", msg or "assertion failed", tostring(actual)))
  end
end

---@param actual                        any
---@param msg                           ?string
local function assert_nil(actual, msg)
  if actual ~= nil then
    error(string.format("%s: expected nil, got %s", msg or "assertion failed", tostring(actual)))
  end
end

----------------------------------------------------------------------------------------------------
-- Constructor tests
----------------------------------------------------------------------------------------------------

test("new: creates pending future", function()
  local future = Future.new()
  assert_false(future:is_done(), "should not be done")
  assert_false(future:is_resolved(), "should not be resolved")
  assert_false(future:is_cancelled(), "should not be cancelled")
  assert_false(future:is_failed(), "should not be failed")
end)

test("new: accepts token in props", function()
  local token = CancellationToken.new()
  local future = Future.new({ token = token })
  assert_false(future:is_done(), "should be pending")
end)

test("new: works with nil props", function()
  local future = Future.new(nil)
  assert_false(future:is_done(), "should create valid future")
end)

----------------------------------------------------------------------------------------------------
-- Executor pattern tests (ES Promise-compatible)
----------------------------------------------------------------------------------------------------

test("new: executor pattern resolves synchronously", function()
  local future = Future.new(function(resolve, reject)
    resolve("sync value")
  end)
  assert_true(future:is_done(), "should be done")
  assert_true(future:is_resolved(), "should be resolved")
  assert_eq("sync value", future:get_result(), "should have value")
end)

test("new: executor pattern rejects synchronously", function()
  local future = Future.new(function(resolve, reject)
    reject("sync error")
  end)
  assert_true(future:is_done(), "should be done")
  assert_true(future:is_failed(), "should be failed")
  assert_eq("sync error", future:get_error(), "should have error")
end)

test("new: executor can store resolve/reject for async use", function()
  local stored_resolve ---@type fun(result: any): nil
  local future = Future.new(function(resolve, reject)
    stored_resolve = resolve
  end)
  assert_false(future:is_done(), "should be pending")

  stored_resolve("async value")
  assert_true(future:is_resolved(), "should be resolved")
  assert_eq("async value", future:get_result(), "should have value")
end)

test("new: executor errors are caught and reject the future", function()
  local future = Future.new(function(resolve, _reject)
    error("executor threw", 0)
  end)
  assert_true(future:is_failed(), "should be failed")
  local err = future:get_error()
  assert_true(err ~= nil and string.find(err, "executor threw") ~= nil, "should have error message")
end)

test("new: second resolve call is ignored", function()
  local future = Future.new(function(resolve, reject)
    resolve("first")
    resolve("second")
  end)
  assert_eq("first", future:get_result(), "should keep first value")
end)

test("new: reject after resolve is ignored", function()
  local future = Future.new(function(resolve, reject)
    resolve("value")
    reject("error")
  end)
  assert_true(future:is_resolved(), "should be resolved")
  assert_nil(future:get_error(), "should have no error")
end)

----------------------------------------------------------------------------------------------------
-- Static constructors
----------------------------------------------------------------------------------------------------

test("resolve: creates resolved future", function()
  local future = Future.resolve("value")
  assert_true(future:is_done(), "should be done")
  assert_true(future:is_resolved(), "should be resolved")
  assert_eq("value", future:get_result(), "should have result")
end)

test("reject: creates rejected future", function()
  local future = Future.reject("error message")
  assert_true(future:is_done(), "should be done")
  assert_true(future:is_failed(), "should be failed")
  assert_eq("error message", future:get_error(), "should have error")
end)

----------------------------------------------------------------------------------------------------
-- State checks
----------------------------------------------------------------------------------------------------

test("is_done: false when pending", function()
  local future = Future.new()
  assert_false(future:is_done())
end)

test("is_done: true when resolved", function()
  local future = Future.new()
  future:__resolve__("value")
  assert_true(future:is_done())
end)

test("is_done: true when rejected", function()
  local future = Future.new()
  future:__reject__("error")
  assert_true(future:is_done())
end)

test("is_done: true when cancelled", function()
  local token = CancellationToken.new()
  local future = Future.new({ token = token })
  token:cancel()
  assert_true(future:is_done())
end)

test("is_resolved: true only when resolved", function()
  local future = Future.new()
  future:__resolve__("value")
  assert_true(future:is_resolved())
  assert_false(future:is_failed())
  assert_false(future:is_cancelled())
end)

test("is_cancelled: true only when cancelled", function()
  local token = CancellationToken.new()
  local future = Future.new({ token = token })
  token:cancel()
  assert_true(future:is_cancelled())
  assert_true(future:is_failed()) -- cancelled is also failed
  assert_false(future:is_resolved())
end)

test("is_failed: true when rejected or cancelled", function()
  local future1 = Future.new()
  future1:__reject__("error")
  assert_true(future1:is_failed())

  local token = CancellationToken.new()
  local future2 = Future.new({ token = token })
  token:cancel()
  assert_true(future2:is_failed())
end)

----------------------------------------------------------------------------------------------------
-- get_result / get_error
----------------------------------------------------------------------------------------------------

test("get_result: returns nil when pending", function()
  local future = Future.new()
  assert_nil(future:get_result())
end)

test("get_result: returns value when resolved", function()
  local future = Future.new()
  future:__resolve__({ key = "value" })
  local result = future:get_result()
  assert_eq("value", result.key)
end)

test("get_error: returns nil when pending", function()
  local future = Future.new()
  assert_nil(future:get_error())
end)

test("get_error: returns error when rejected", function()
  local future = Future.new()
  future:__reject__("my error")
  assert_eq("my error", future:get_error())
end)

test("get_error: returns error when cancelled", function()
  local token = CancellationToken.new()
  local future = Future.new({ token = token })
  token:cancel()
  local err = future:get_error()
  assert_true(err ~= nil and string.find(err, "cancelled") ~= nil)
end)

----------------------------------------------------------------------------------------------------
-- finally tests
----------------------------------------------------------------------------------------------------

test("finally: called immediately if already resolved", function()
  local future = Future.resolve("value")
  local called = false
  local received_ok = nil
  local received_result = nil

  future:finally(function(ok, result)
    called = true
    received_ok = ok
    received_result = result
  end)

  assert_true(called, "should be called immediately")
  assert_true(received_ok, "ok should be true")
  assert_eq("value", received_result, "result should be value")
end)

test("finally: called immediately if already rejected", function()
  local future = Future.reject("error")
  local called = false
  local received_ok = nil
  local received_result = nil

  future:finally(function(ok, result)
    called = true
    received_ok = ok
    received_result = result
  end)

  assert_true(called, "should be called immediately")
  assert_false(received_ok, "ok should be false")
  assert_eq("error", received_result, "result should be error")
end)

test("finally: queued when pending, called on resolve", function()
  local future = Future.new()
  local called = false
  local received_ok = nil
  local received_result = nil

  future:finally(function(ok, result)
    called = true
    received_ok = ok
    received_result = result
  end)

  assert_false(called, "should not be called yet")

  future:__resolve__("done")

  assert_true(called, "should be called after resolve")
  assert_true(received_ok, "ok should be true")
  assert_eq("done", received_result, "result should be value")
end)

test("finally: queued when pending, called on reject", function()
  local future = Future.new()
  local called = false
  local received_ok = nil

  future:finally(function(ok, result)
    called = true
    received_ok = ok
  end)

  future:__reject__("failed")

  assert_true(called, "should be called after reject")
  assert_false(received_ok, "ok should be false")
end)

test("finally: multiple listeners all called", function()
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
  assert_eq(3, count, "all listeners called")
end)

test("finally: handles callback errors gracefully", function()
  local future = Future.new()
  local second_called = false

  future:finally(function()
    error("intentional error")
  end)
  future:finally(function()
    second_called = true
  end)

  future:__resolve__("value")
  assert_true(second_called, "second listener should still be called")
end)

----------------------------------------------------------------------------------------------------
-- __resolve__ tests
----------------------------------------------------------------------------------------------------

test("__resolve__: transitions state to resolved", function()
  local future = Future.new()
  future:__resolve__("value")
  assert_eq("value", future:get_result())
  assert_true(future:is_resolved())
end)

test("__resolve__: is idempotent (second call ignored)", function()
  local future = Future.new()
  future:__resolve__("first")
  future:__resolve__("second")
  assert_eq("first", future:get_result(), "should keep first value")
end)

test("__resolve__: ignored if already rejected", function()
  local future = Future.new()
  future:__reject__("error")
  future:__resolve__("value")
  assert_true(future:is_failed(), "should still be failed")
  assert_nil(future:get_result(), "should have no result")
end)

----------------------------------------------------------------------------------------------------
-- __reject__ tests
----------------------------------------------------------------------------------------------------

test("__reject__: transitions state to rejected", function()
  local future = Future.new()
  future:__reject__("error")
  assert_eq("error", future:get_error())
  assert_true(future:is_failed())
end)

test("__reject__: is idempotent (second call ignored)", function()
  local future = Future.new()
  future:__reject__("first error")
  future:__reject__("second error")
  assert_eq("first error", future:get_error(), "should keep first error")
end)

test("__reject__: ignored if already resolved", function()
  local future = Future.new()
  future:__resolve__("value")
  future:__reject__("error")
  assert_true(future:is_resolved(), "should still be resolved")
  assert_nil(future:get_error(), "should have no error")
end)

----------------------------------------------------------------------------------------------------
-- Cancellation tests
----------------------------------------------------------------------------------------------------

test("cancel: token cancellation cancels future", function()
  local token = CancellationToken.new()
  local future = Future.new({ token = token })

  assert_false(future:is_cancelled(), "should not be cancelled yet")

  token:cancel()

  assert_true(future:is_cancelled(), "should be cancelled")
  assert_true(future:is_done(), "should be done")
end)

test("cancel: finally called on cancellation", function()
  local token = CancellationToken.new()
  local future = Future.new({ token = token })
  local called = false
  local received_ok = nil

  future:finally(function(ok, _)
    called = true
    received_ok = ok
  end)

  token:cancel()

  assert_true(called, "finally should be called")
  assert_false(received_ok, "ok should be false for cancellation")
end)

test("cancel: resolve after cancel is ignored", function()
  local token = CancellationToken.new()
  local future = Future.new({ token = token })

  token:cancel()
  future:__resolve__("value")

  assert_true(future:is_cancelled(), "should remain cancelled")
  assert_nil(future:get_result(), "should have no result")
end)

----------------------------------------------------------------------------------------------------
-- IDisposable interface tests
----------------------------------------------------------------------------------------------------

test("isdisposed: false when pending", function()
  local future = Future.new()
  assert_false(future:isdisposed())
end)

test("isdisposed: true when done", function()
  local future = Future.new()
  future:__resolve__("value")
  assert_true(future:isdisposed())
end)

test("dispose: cancels via token", function()
  local token = CancellationToken.new()
  local future = Future.new({ token = token })

  local result = future:dispose()

  assert_true(result, "dispose should return true")
  assert_true(future:is_cancelled(), "should be cancelled")
end)

test("dispose: returns false without token", function()
  local future = Future.new()
  local result = future:dispose()
  assert_false(result, "dispose should return false without token")
end)

----------------------------------------------------------------------------------------------------
-- then_ tests
----------------------------------------------------------------------------------------------------

test("then_: chains resolved future", function()
  local future = Future.resolve(10)
  local chained = future:then_(function(result)
    return result * 2
  end)
  assert_true(chained:is_resolved())
  assert_eq(20, chained:get_result())
end)

test("then_: chains rejected future with on_rejected", function()
  local future = Future.reject("error")
  local chained = future:then_(nil, function(err)
    return "recovered: " .. err
  end)
  assert_true(chained:is_resolved())
  assert_eq("recovered: error", chained:get_result())
end)

test("then_: propagates rejection without on_rejected", function()
  local future = Future.reject("error")
  local chained = future:then_(function(result)
    return result * 2
  end)
  assert_true(chained:is_failed())
  assert_eq("error", chained:get_error())
end)

test("then_: propagates resolution without on_resolved", function()
  local future = Future.resolve("value")
  local chained = future:then_(nil, function(err)
    return "recovered"
  end)
  assert_true(chained:is_resolved())
  assert_eq("value", chained:get_result())
end)

test("then_: handles callback errors", function()
  local future = Future.resolve("value")
  local chained = future:then_(function(_)
    error("callback error", 0)
  end)
  assert_true(chained:is_failed())
  local err = chained:get_error()
  assert_true(err ~= nil and string.find(err, "callback error") ~= nil)
end)

test("then_: waits for returned future", function()
  local inner, resolver = Future.new_with_resolver()
  local future = Future.resolve("value")
  local chained = future:then_(function(_)
    return inner
  end)

  assert_false(chained:is_done(), "should wait for inner future")

  resolver("inner result")
  assert_true(chained:is_resolved())
  assert_eq("inner result", chained:get_result())
end)

test("then_: chained calls work correctly", function()
  local future = Future.resolve(1)
  local chained = future
    :then_(function(x) return x + 1 end)
    :then_(function(x) return x * 2 end)
    :then_(function(x) return x + 10 end)

  assert_true(chained:is_resolved())
  assert_eq(14, chained:get_result()) -- ((1+1)*2)+10 = 14
end)

test("then_: pending future chains correctly", function()
  local future, resolver = Future.new_with_resolver()
  local chained = future:then_(function(result)
    return result .. "!"
  end)

  assert_false(chained:is_done(), "should be pending")

  resolver("hello")
  assert_true(chained:is_resolved())
  assert_eq("hello!", chained:get_result())
end)

----------------------------------------------------------------------------------------------------
-- catch tests
----------------------------------------------------------------------------------------------------

test("catch: catches rejected future", function()
  local future = Future.reject("error")
  local caught = future:catch(function(err)
    return "caught: " .. err
  end)
  assert_true(caught:is_resolved())
  assert_eq("caught: error", caught:get_result())
end)

test("catch: passes through resolved future", function()
  local future = Future.resolve("value")
  local caught = future:catch(function(err)
    return "caught"
  end)
  assert_true(caught:is_resolved())
  assert_eq("value", caught:get_result())
end)

test("catch: catches cancelled future", function()
  local token = CancellationToken.new()
  local future = Future.new({ token = token })
  local caught = future:catch(function(err)
    return "caught cancel"
  end)

  token:cancel()
  assert_true(caught:is_resolved())
  assert_eq("caught cancel", caught:get_result())
end)

----------------------------------------------------------------------------------------------------
-- map tests
----------------------------------------------------------------------------------------------------

test("map: transforms resolved value", function()
  local future = Future.resolve(5)
  local mapped = future:map(function(x)
    return x * 3
  end)
  assert_true(mapped:is_resolved())
  assert_eq(15, mapped:get_result())
end)

test("map: propagates rejection", function()
  local future = Future.reject("error")
  local mapped = future:map(function(x)
    return x * 3
  end)
  assert_true(mapped:is_failed())
  assert_eq("error", mapped:get_error())
end)

test("map: handles callback errors", function()
  local future = Future.resolve(5)
  local mapped = future:map(function(_)
    error("map error", 0)
  end)
  assert_true(mapped:is_failed())
  local err = mapped:get_error()
  assert_true(err ~= nil and string.find(err, "map error") ~= nil)
end)

----------------------------------------------------------------------------------------------------
-- Future.all tests
----------------------------------------------------------------------------------------------------

test("all: resolves with empty array for empty input", function()
  local future = Future.all({})
  assert_true(future:is_resolved())
  local result = future:get_result()
  assert_eq(0, #result)
end)

test("all: resolves when all futures resolve", function()
  local f1 = Future.resolve(1)
  local f2 = Future.resolve(2)
  local f3 = Future.resolve(3)

  local future = Future.all({ f1, f2, f3 })
  assert_true(future:is_resolved())

  local result = future:get_result()
  assert_eq(1, result[1])
  assert_eq(2, result[2])
  assert_eq(3, result[3])
end)

test("all: rejects immediately on first rejection", function()
  local f1 = Future.resolve(1)
  local f2 = Future.reject("error2")
  local f3 = Future.resolve(3)

  local future = Future.all({ f1, f2, f3 })
  assert_true(future:is_failed())
  assert_eq("error2", future:get_error())
end)

test("all: preserves order of results", function()
  local f1, r1 = Future.new_with_resolver()
  local f2, r2 = Future.new_with_resolver()
  local f3, r3 = Future.new_with_resolver()

  local future = Future.all({ f1, f2, f3 })

  r3("third")
  r1("first")
  r2("second")

  assert_true(future:is_resolved())
  local result = future:get_result()
  assert_eq("first", result[1])
  assert_eq("second", result[2])
  assert_eq("third", result[3])
end)

test("all: supports token cancellation", function()
  local token = CancellationToken.new()
  local f1 = Future.resolve(1)
  local f2 = Future.new()

  local future = Future.all({ f1, f2 }, token)

  assert_false(future:is_done())

  token:cancel()
  assert_true(future:is_cancelled())
end)

test("all: ignores late results after rejection", function()
  local f1, r1 = Future.new_with_resolver()
  local f2 = Future.reject("early error")

  local future = Future.all({ f1, f2 })

  assert_true(future:is_failed())
  assert_eq("early error", future:get_error())

  r1("late value")
  assert_eq("early error", future:get_error())
end)

----------------------------------------------------------------------------------------------------
-- Future.race tests
----------------------------------------------------------------------------------------------------

test("race: returns pending for empty input", function()
  local future = Future.race({})
  assert_false(future:is_done())
end)

test("race: resolves with first resolved future", function()
  local f1, r1 = Future.new_with_resolver()
  local f2 = Future.resolve("winner")
  local f3 = Future.new()

  local future = Future.race({ f1, f2, f3 })
  assert_true(future:is_resolved())
  assert_eq("winner", future:get_result())
end)

test("race: rejects with first rejected future", function()
  local f1 = Future.new()
  local f2 = Future.reject("loser")
  local f3 = Future.new()

  local future = Future.race({ f1, f2, f3 })
  assert_true(future:is_failed())
  assert_eq("loser", future:get_error())
end)

test("race: ignores late results", function()
  local f1, r1 = Future.new_with_resolver()
  local f2, r2 = Future.new_with_resolver()

  local future = Future.race({ f1, f2 })

  r1("first")
  assert_true(future:is_resolved())
  assert_eq("first", future:get_result())

  r2("second")
  assert_eq("first", future:get_result())
end)

test("race: supports token cancellation", function()
  local token = CancellationToken.new()
  local f1 = Future.new()
  local f2 = Future.new()

  local future = Future.race({ f1, f2 }, token)

  assert_false(future:is_done())

  token:cancel()
  assert_true(future:is_cancelled())
end)

----------------------------------------------------------------------------------------------------
-- Future.any tests
----------------------------------------------------------------------------------------------------

test("any: rejects for empty input", function()
  local future = Future.any({})
  assert_true(future:is_failed())
  assert_eq("All futures rejected", future:get_error())
end)

test("any: resolves with first resolved future", function()
  local f1 = Future.reject("error1")
  local f2 = Future.resolve("winner")
  local f3 = Future.reject("error3")

  local future = Future.any({ f1, f2, f3 })
  assert_true(future:is_resolved())
  assert_eq("winner", future:get_result())
end)

test("any: rejects when all futures reject", function()
  local f1 = Future.reject("error1")
  local f2 = Future.reject("error2")
  local f3 = Future.reject("error3")

  local future = Future.any({ f1, f2, f3 })
  assert_true(future:is_failed())
  assert_eq("All futures rejected", future:get_error())
end)

test("any: ignores rejections before first resolution", function()
  local f1, r1 = Future.new_with_resolver()
  local f2 = Future.reject("error")
  local f3, r3 = Future.new_with_resolver()

  local future = Future.any({ f1, f2, f3 })

  assert_false(future:is_done(), "should wait for potential success")

  r3("success")
  assert_true(future:is_resolved())
  assert_eq("success", future:get_result())
end)

test("any: supports token cancellation", function()
  local token = CancellationToken.new()
  local f1 = Future.reject("error")
  local f2 = Future.new()

  local future = Future.any({ f1, f2 }, token)

  assert_false(future:is_done())

  token:cancel()
  assert_true(future:is_cancelled())
end)

test("any: ignores late results after first success", function()
  local f1, r1 = Future.new_with_resolver()
  local f2, r2 = Future.new_with_resolver()

  local future = Future.any({ f1, f2 })

  r1("first")
  assert_true(future:is_resolved())
  assert_eq("first", future:get_result())

  r2("second")
  assert_eq("first", future:get_result())
end)

----------------------------------------------------------------------------------------------------
-- Future.allSettled tests
----------------------------------------------------------------------------------------------------

test("allSettled: resolves with empty array for empty input", function()
  local future = Future.allSettled({})
  assert_true(future:is_resolved())
  local result = future:get_result()
  assert_eq(0, #result)
end)

test("allSettled: resolves with all results when all futures resolve", function()
  local f1 = Future.resolve(1)
  local f2 = Future.resolve(2)
  local f3 = Future.resolve(3)

  local future = Future.allSettled({ f1, f2, f3 })
  assert_true(future:is_resolved())

  local result = future:get_result()
  assert_eq(3, #result)
  assert_eq("fulfilled", result[1].status)
  assert_eq(1, result[1].value)
  assert_eq("fulfilled", result[2].status)
  assert_eq(2, result[2].value)
  assert_eq("fulfilled", result[3].status)
  assert_eq(3, result[3].value)
end)

test("allSettled: resolves with all results when some futures reject", function()
  local f1 = Future.resolve("ok")
  local f2 = Future.reject("error2")
  local f3 = Future.resolve("also ok")

  local future = Future.allSettled({ f1, f2, f3 })
  assert_true(future:is_resolved(), "should always resolve")

  local result = future:get_result()
  assert_eq(3, #result)
  assert_eq("fulfilled", result[1].status)
  assert_eq("ok", result[1].value)
  assert_eq("rejected", result[2].status)
  assert_eq("error2", result[2].reason)
  assert_eq("fulfilled", result[3].status)
  assert_eq("also ok", result[3].value)
end)

test("allSettled: resolves with all results when all futures reject", function()
  local f1 = Future.reject("error1")
  local f2 = Future.reject("error2")

  local future = Future.allSettled({ f1, f2 })
  assert_true(future:is_resolved(), "should always resolve")

  local result = future:get_result()
  assert_eq(2, #result)
  assert_eq("rejected", result[1].status)
  assert_eq("error1", result[1].reason)
  assert_eq("rejected", result[2].status)
  assert_eq("error2", result[2].reason)
end)

test("allSettled: preserves order of results", function()
  local f1, r1 = Future.new_with_resolver()
  local f2, r2 = Future.new_with_resolver()
  local f3, r3 = Future.new_with_resolver()

  local future = Future.allSettled({ f1, f2, f3 })

  r3("third")
  r1("first")
  r2("second")

  assert_true(future:is_resolved())
  local result = future:get_result()
  assert_eq("first", result[1].value)
  assert_eq("second", result[2].value)
  assert_eq("third", result[3].value)
end)

test("allSettled: supports token cancellation", function()
  local token = CancellationToken.new()
  local f1 = Future.resolve(1)
  local f2 = Future.new()

  local future = Future.allSettled({ f1, f2 }, token)

  assert_false(future:is_done())

  token:cancel()
  assert_true(future:is_cancelled())
end)

----------------------------------------------------------------------------------------------------
-- Summary
----------------------------------------------------------------------------------------------------

print(string.format("\n%d passed, %d failed", passed, failed))

if failed > 0 then
  os.exit(1)
end
