--- Run with: nvim -l __test__/run.lua __test__/specs/support/harness_spec.lua
---@diagnostic disable: undefined-global, invisible
--- Test for __test__.support.harness module

local harness = require("__test__.support.harness")

local t = harness.new("__test__.support.harness")

---@param callback                      fun(inner: __test__.support.Harness)
---@return __test__.support.harness.IResult
local function run_inner(callback)
  local inner = harness.new("inner")
  inner:test("case", function()
    callback(inner)
  end)
  return inner:run({ exit = false, quiet = true })
end

t:test("run: returns result without exiting", function()
  local result = run_inner(function() end)
  t.assert_eq("inner", result.name, "suite name")
  t.assert_eq(1, result.passed, "passed count")
  t.assert_eq(0, result.failed, "failed count")
end)

t:test("patch_table: restores own value with raw table access", function()
  local target = setmetatable({}, {
    __index = {
      value = "inherited",
    },
  })

  local result = run_inner(function(inner)
    inner:patch_table(target, "value", "patched")
    t.assert_eq("patched", target.value, "patched value")
  end)

  t.assert_eq(1, result.passed, "inner case should pass")
  t.assert_nil(rawget(target, "value"), "own value should be removed")
  t.assert_eq("inherited", target.value, "inherited value should remain visible")
end)

t:test("patch_global: restores original global after case", function()
  t:patch_global("__test_harness_probe", "original")

  local result = run_inner(function(inner)
    inner:patch_global("__test_harness_probe", "patched")
    t.assert_eq("patched", rawget(_G, "__test_harness_probe"), "patched global")
  end)

  t.assert_eq(1, result.passed, "inner case should pass")
  t.assert_eq("original", rawget(_G, "__test_harness_probe"), "restored global")
end)

t:test("defer restores case resources in reverse order after a failure", function()
  local events = {} ---@type integer[]
  local result = run_inner(function(inner)
    inner:defer(function()
      events[#events + 1] = 1
    end)
    inner:defer(function()
      events[#events + 1] = 2
    end)
    error("expected case failure")
  end)
  t.assert_eq(1, result.failed, "failed case")
  t.assert_eq(2, events[1], "last registered cleanup")
  t.assert_eq(1, events[2], "first registered cleanup")
end)

t:test("defer cleanup handles are idempotent", function()
  local calls = 0 ---@type integer
  local result = run_inner(function(inner)
    local cleanup = inner:defer(function()
      calls = calls + 1
    end)
    cleanup()
    cleanup()
  end)
  t.assert_eq(0, result.failed, "case result")
  t.assert_eq(1, calls, "exactly one cleanup")
end)

t:test("cleanup errors preserve the original failure and do not skip other cleanups", function()
  local cleaned = false ---@type boolean
  local result = run_inner(function(inner)
    inner:defer(function()
      cleaned = true
    end)
    inner:defer(function()
      error("expected cleanup failure")
    end)
    error("expected case failure")
  end)
  t.assert_true(cleaned, "remaining cleanup")
  t.assert_eq(1, result.failed, "failed case count")
  t.assert_eq(2, #result.failures, "case and cleanup diagnostics")
end)

t:test("an empty suite fails and still disposes suite resources", function()
  local inner = harness.new("empty")
  local cleaned = false ---@type boolean
  inner:defer(function()
    cleaned = true
  end)
  local result = inner:run({ exit = false, quiet = true })
  t.assert_eq(1, result.failed, "empty suite failure")
  t.assert_true(cleaned, "suite cleanup")
end)

t:test("suite resources survive cases and are disposed after the final case", function()
  local inner = harness.new("suite cleanup")
  local live = true ---@type boolean
  inner:defer(function()
    live = false
  end)
  for index = 1, 2 do
    inner:test("case " .. index, function()
      t.assert_true(live, "suite resource during a case")
    end)
  end
  local result = inner:run({ exit = false, quiet = true })
  t.assert_eq(2, result.passed, "both cases")
  t.assert_false(live, "suite resource disposed")
end)

t:run()
