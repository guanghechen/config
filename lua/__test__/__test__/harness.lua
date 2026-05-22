---@diagnostic disable: undefined-global, invisible
--- Test for __test__.harness module
--- Run with: nvim -l lua/__test__/__test__/harness.lua

local harness = require("__test__.harness")

local t = harness.new("__test__.harness")

---@param callback                      fun(inner: __test__.Harness)
---@return __test__.harness.IResult
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

t:run()
