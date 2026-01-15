---@diagnostic disable: undefined-global
--- Test for stl.c.CancellationToken module
--- Run with: nvim -l lua/__test__/stl/c/cancellation_token_test.lua

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

----------------------------------------------------------------------------------------------------
-- Constructor tests
----------------------------------------------------------------------------------------------------

test("new: creates token with cancelled=false", function()
  local token = CancellationToken.new()
  assert_false(token:is_cancelled(), "should not be cancelled initially")
end)

test("new: accepts on_cancel callback in props", function()
  local called = false
  local token = CancellationToken.new({
    on_cancel = function()
      called = true
    end,
  })
  token:cancel()
  assert_true(called, "on_cancel callback should be invoked")
end)

test("new: works with nil props", function()
  local token = CancellationToken.new(nil)
  assert_false(token:is_cancelled(), "should create valid token")
end)

----------------------------------------------------------------------------------------------------
-- is_cancelled tests
----------------------------------------------------------------------------------------------------

test("is_cancelled: returns false before cancel", function()
  local token = CancellationToken.new()
  assert_false(token:is_cancelled(), "should be false")
end)

test("is_cancelled: returns true after cancel", function()
  local token = CancellationToken.new()
  token:cancel()
  assert_true(token:is_cancelled(), "should be true")
end)

----------------------------------------------------------------------------------------------------
-- cancel tests
----------------------------------------------------------------------------------------------------

test("cancel: triggers registered callbacks", function()
  local token = CancellationToken.new()
  local called = false
  token:on_cancel(function()
    called = true
  end)
  token:cancel()
  assert_true(called, "callback should be called")
end)

test("cancel: triggers multiple callbacks in order", function()
  local token = CancellationToken.new()
  local order = {}
  token:on_cancel(function()
    order[#order + 1] = 1
  end)
  token:on_cancel(function()
    order[#order + 1] = 2
  end)
  token:on_cancel(function()
    order[#order + 1] = 3
  end)
  token:cancel()
  assert_eq(3, #order, "all callbacks called")
  assert_eq(1, order[1], "first callback first")
  assert_eq(2, order[2], "second callback second")
  assert_eq(3, order[3], "third callback third")
end)

test("cancel: is idempotent (second call does nothing)", function()
  local token = CancellationToken.new()
  local call_count = 0
  token:on_cancel(function()
    call_count = call_count + 1
  end)
  token:cancel()
  token:cancel()
  token:cancel()
  assert_eq(1, call_count, "callback should only be called once")
end)

test("cancel: clears callbacks after execution", function()
  local token = CancellationToken.new()
  local called = false
  token:on_cancel(function()
    called = true
  end)
  token:cancel()
  -- Internal _callbacks should be empty now
  assert_true(called, "callback was called")
end)

test("cancel: handles callback errors gracefully", function()
  local token = CancellationToken.new()
  local second_called = false
  token:on_cancel(function()
    error("intentional error")
  end)
  token:on_cancel(function()
    second_called = true
  end)
  -- Should not throw
  token:cancel()
  assert_true(second_called, "second callback should still be called")
end)

----------------------------------------------------------------------------------------------------
-- on_cancel tests
----------------------------------------------------------------------------------------------------

test("on_cancel: returns unsubscribable", function()
  local token = CancellationToken.new()
  local sub = token:on_cancel(function() end)
  assert_true(sub ~= nil, "should return subscription")
  assert_true(type(sub.unsubscribe) == "function", "should have unsubscribe function")
end)

test("on_cancel: unsubscribe prevents callback", function()
  local token = CancellationToken.new()
  local called = false
  local sub = token:on_cancel(function()
    called = true
  end)
  sub:unsubscribe()
  token:cancel()
  assert_false(called, "callback should not be called after unsubscribe")
end)

test("on_cancel: unsubscribe is idempotent", function()
  local token = CancellationToken.new()
  local sub = token:on_cancel(function() end)
  sub:unsubscribe()
  sub:unsubscribe() -- Should not throw
  sub:unsubscribe()
end)

test("on_cancel: immediate callback if already cancelled", function()
  local token = CancellationToken.new()
  token:cancel()

  local called = false
  token:on_cancel(function()
    called = true
  end)
  assert_true(called, "callback should be called immediately")
end)

test("on_cancel: returns noop unsubscribe if already cancelled", function()
  local token = CancellationToken.new()
  token:cancel()

  local sub = token:on_cancel(function() end)
  -- Should not throw
  sub:unsubscribe()
end)

----------------------------------------------------------------------------------------------------
-- throw_if_cancelled tests
----------------------------------------------------------------------------------------------------

test("throw_if_cancelled: does nothing if not cancelled", function()
  local token = CancellationToken.new()
  -- Should not throw
  token:throw_if_cancelled()
end)

test("throw_if_cancelled: throws if cancelled", function()
  local token = CancellationToken.new()
  token:cancel()

  local threw = false
  local ok, err = pcall(function()
    token:throw_if_cancelled()
  end)
  if not ok then
    threw = true
    assert_true(type(err) == "string" and string.find(err, "cancelled") ~= nil, "error message should mention cancelled")
  end
  assert_true(threw, "should throw error")
end)

----------------------------------------------------------------------------------------------------
-- IDisposable interface tests
----------------------------------------------------------------------------------------------------

test("isdisposed: returns false before cancel", function()
  local token = CancellationToken.new()
  assert_false(token:isdisposed(), "should not be disposed")
end)

test("isdisposed: returns true after cancel", function()
  local token = CancellationToken.new()
  token:cancel()
  assert_true(token:isdisposed(), "should be disposed")
end)

test("dispose: cancels the token", function()
  local token = CancellationToken.new()
  local called = false
  token:on_cancel(function()
    called = true
  end)
  token:dispose()
  assert_true(token:is_cancelled(), "should be cancelled")
  assert_true(called, "callback should be called")
end)

test("dispose: returns true on first call", function()
  local token = CancellationToken.new()
  local result = token:dispose()
  assert_true(result, "should return true on first dispose")
end)

test("dispose: returns false on subsequent calls", function()
  local token = CancellationToken.new()
  token:dispose()
  local result = token:dispose()
  assert_false(result, "should return false on second dispose")
end)

----------------------------------------------------------------------------------------------------
-- Summary
----------------------------------------------------------------------------------------------------

print(string.format("\n%d passed, %d failed", passed, failed))

if failed > 0 then
  os.exit(1)
end
