local harness = require("__test__.support.harness")
local CancellationToken = require("stl.c.cancellation_token")

local t = harness.new()

t:test("new: accepts on_cancel callback in props", function()
  local called = false
  local token = CancellationToken.new({
    on_cancel = function()
      called = true
    end,
  })
  token:cancel()
  t.assert_true(called, "on_cancel callback should be invoked")
end)

-- isdisposed mirrors is_cancelled.
for _, case in ipairs({
  { name = "is_cancelled: returns false before cancel", method = "is_cancelled", cancel = false },
  { name = "is_cancelled: returns true after cancel", method = "is_cancelled", cancel = true },
  { name = "isdisposed: returns false before cancel", method = "isdisposed", cancel = false },
  { name = "isdisposed: returns true after cancel", method = "isdisposed", cancel = true },
}) do
  t:test(case.name, function()
    local token = CancellationToken.new()
    if case.cancel then
      token:cancel()
    end
    t.assert_eq(case.cancel, token[case.method](token), case.method)
  end)
end

t:test("cancel: triggers registered callbacks", function()
  local token = CancellationToken.new()
  local called = false
  token:on_cancel(function()
    called = true
  end)
  token:cancel()
  t.assert_true(called, "callback should be called")
end)

t:test("cancel: triggers multiple callbacks in order", function()
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
  t.assert_same({ 1, 2, 3 }, order, "all callbacks called, in registration order")
end)

t:test("cancel: is idempotent (second call does nothing)", function()
  local token = CancellationToken.new()
  local call_count = 0
  token:on_cancel(function()
    call_count = call_count + 1
  end)
  token:cancel()
  token:cancel()
  token:cancel()
  t.assert_eq(1, call_count, "callback should only be called once")
end)

t:test("cancel: clears callbacks after execution", function()
  local token = CancellationToken.new()
  local called = false
  local registered = setmetatable({}, { __mode = "k" }) ---@type table<function, true>
  -- Registers from a frame of its own, so that only the token holds the callback.
  local function register()
    local callback = function()
      called = true
    end
    registered[callback] = true
    token:on_cancel(callback)
  end
  register()
  collectgarbage("collect")
  t.assert_true(next(registered) ~= nil, "the token holds the callback until it runs")

  token:cancel()
  t.assert_true(called, "callback was called")
  collectgarbage("collect")
  t.assert_nil(next(registered), "the token released the callback after running it")
end)

t:test("cancel: handles callback errors gracefully", function()
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
  t.assert_true(second_called, "second callback should still be called")
end)

t:test("cancel: a callback that unsubscribes itself does not skip the next one", function()
  -- stl.c.Future does exactly this from __cleanup__. Removing an entry from the array being
  -- iterated used to shift it left, so ipairs skipped every second callback.
  local token = CancellationToken.new()
  local fired = {} ---@type integer[]
  local subs = {} ---@type stl.c.IUnsubscribable[]

  for i = 1, 4 do
    subs[i] = token:on_cancel(function()
      fired[#fired + 1] = i
      ---@diagnostic disable-next-line: missing-parameter
      subs[i].unsubscribe()
    end)
  end

  token:cancel()
  t.assert_eq("1,2,3,4", table.concat(fired, ","), "every callback fires exactly once, in order")
end)

t:test("cancel: a self-unsubscribing callback does not hide its neighbours", function()
  -- Mixed shape: one self-unsubscribing callback plus plain work-cancelling ones.
  local token = CancellationToken.new()
  local aborted = {} ---@type string[]

  local sub = token:on_cancel(function()
    ---@diagnostic disable-next-line: need-check-nil
    sub.unsubscribe()
  end)
  token:on_cancel(function()
    aborted[#aborted + 1] = "job-1"
  end)
  token:on_cancel(function()
    aborted[#aborted + 1] = "job-2"
  end)

  token:cancel()
  t.assert_eq("job-1,job-2", table.concat(aborted, ","), "both abort callbacks run")
end)

t:test("on_cancel: returns unsubscribable", function()
  local token = CancellationToken.new()
  local sub = token:on_cancel(function() end)
  t.assert_true(sub ~= nil, "should return subscription")
  t.assert_true(type(sub.unsubscribe) == "function", "should have unsubscribe function")
end)

t:test("on_cancel: unsubscribe prevents callback", function()
  local token = CancellationToken.new()
  local called = false
  local sub = token:on_cancel(function()
    called = true
  end)
  sub:unsubscribe()
  token:cancel()
  t.assert_false(called, "callback should not be called after unsubscribe")
end)

t:test("on_cancel: unsubscribe is idempotent", function()
  local token = CancellationToken.new()
  local calls = 0 ---@type integer
  local function callback()
    calls = calls + 1
  end
  local sub = token:on_cancel(callback)
  token:on_cancel(callback)
  sub:unsubscribe()
  sub:unsubscribe() -- Should not throw
  sub:unsubscribe()
  token:cancel()
  t.assert_eq(1, calls, "repeated unsubscribes remove only their own registration")
end)

t:test("on_cancel: immediate callback if already cancelled", function()
  local token = CancellationToken.new()
  token:cancel()

  local called = false
  token:on_cancel(function()
    called = true
  end)
  t.assert_true(called, "callback should be called immediately")
end)

t:test("on_cancel: returns noop unsubscribe if already cancelled", function()
  local token = CancellationToken.new()
  token:cancel()

  local calls = 0 ---@type integer
  local sub = token:on_cancel(function()
    calls = calls + 1
  end)
  -- Should not throw
  sub:unsubscribe()
  t.assert_eq(1, calls, "only the immediate call runs the callback")
  t.assert_true(token:is_cancelled(), "the token stays cancelled")
end)

t:test("throw_if_cancelled: does nothing if not cancelled", function()
  local token = CancellationToken.new()
  -- Should not throw
  token:throw_if_cancelled()
  t.assert_false(token:is_cancelled(), "the check leaves the token active")
end)

t:test("throw_if_cancelled: throws if cancelled", function()
  local token = CancellationToken.new()
  token:cancel()

  t.assert_error(function()
    token:throw_if_cancelled()
  end, "cancelled", "should throw error")
end)

t:test("dispose: cancels the token", function()
  local token = CancellationToken.new()
  local called = false
  token:on_cancel(function()
    called = true
  end)
  token:dispose()
  t.assert_true(token:is_cancelled(), "should be cancelled")
  t.assert_true(called, "callback should be called")
end)

-- Only the first disposal cancels the token.
for _, case in ipairs({
  { name = "dispose: returns true on first call", disposals = 1, result = true },
  { name = "dispose: returns false on subsequent calls", disposals = 2, result = false },
}) do
  t:test(case.name, function()
    local token = CancellationToken.new()
    local result ---@type boolean
    for _ = 1, case.disposals do
      result = token:dispose()
    end
    t.assert_eq(case.result, result, "result of dispose call " .. case.disposals)
  end)
end

t:run()
