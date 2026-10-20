local harness = require("__test__.support.harness")

local t = harness.new()

---@param callback                      fun(inner: __test__.support.Harness)
---@return __test__.support.harness.IResult
local function run_inner(callback)
  local inner = harness.new()
  inner:test("case", function()
    callback(inner)
  end)
  return inner:run({ exit = false, quiet = true })
end

t:test("run: returns result without exiting", function()
  local result = run_inner(function() end)
  t.assert_eq(t.name, result.name, "suites are named after their script")
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
  local inner = harness.new()
  local cleaned = false ---@type boolean
  inner:defer(function()
    cleaned = true
  end)
  local result = inner:run({ exit = false, quiet = true })
  t.assert_eq(1, result.failed, "empty suite failure")
  t.assert_true(cleaned, "suite cleanup")
end)

t:test("suite resources survive cases and are disposed after the final case", function()
  local inner = harness.new()
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

t:test("skip ends a case without passing or failing and still runs its cleanups", function()
  local cleaned = false ---@type boolean
  local after_skip = false ---@type boolean
  local result = run_inner(function(inner)
    inner:defer(function()
      cleaned = true
    end)
    inner.skip("unsupported environment")
    after_skip = true
  end)
  t.assert_eq(0, result.passed, "passed count")
  t.assert_eq(0, result.failed, "failed count")
  t.assert_eq(1, result.skipped, "skipped count")
  t.assert_false(after_skip, "case stops at skip")
  t.assert_true(cleaned, "cleanup")
end)

t:test("a cleanup failure after skip still fails the case", function()
  local result = run_inner(function(inner)
    inner:defer(function()
      error("expected cleanup failure")
    end)
    inner.skip("unsupported environment")
  end)
  t.assert_eq(1, result.failed, "failed count")
  t.assert_eq(0, result.skipped, "skipped count")
  t.assert_eq(1, #result.failures, "cleanup diagnostic only")
end)

---@param done                          boolean
---@param error_value                   ?string
---@param result                        ?any
---@return table
local function future(done, error_value, result)
  return {
    is_done = function()
      return done
    end,
    is_failed = function()
      return error_value ~= nil
    end,
    get_error = function()
      return error_value
    end,
    get_result = function()
      return result
    end,
  }
end

t:test("await returns a settled result and fails on a failed or unsettled future", function()
  t.assert_eq(7, t.await(future(true, nil, 7)))
  local ok, err = pcall(t.await, future(true, "boom"))
  t.assert_false(ok, "failed future")
  t.assert_true(tostring(err):find("boom", 1, true) ~= nil, tostring(err))
  t.assert_false(pcall(t.await, future(false), 20), "unsettled future")
end)

t:test("assert_same compares structurally and shows both sides", function()
  t.assert_same({ a = { 1, 2 } }, { a = { 1, 2 } })
  local ok, err = pcall(t.assert_same, { 1 }, { 2 }, "values")
  t.assert_false(ok, "different values")
  t.assert_true(tostring(err):find("values: expected { 1 }, got { 2 }", 1, true) ~= nil, tostring(err))
end)

t:test("tempdir lives under the system temporary directory until its case ends", function()
  local path ---@type string
  local result = run_inner(function(inner)
    path = inner:tempdir()
    vim.fn.writefile({ "x" }, path .. "/file")
    t.assert_true(vim.startswith(path, assert(vim.uv.fs_realpath(vim.uv.os_tmpdir()))), path)
  end)
  t.assert_eq(1, result.passed)
  t.assert_nil(vim.uv.fs_stat(path), "removed with its case")
end)

t:run()
