---@diagnostic disable: undefined-global

local harness = require("__test__.harness")

local t = harness.new("era.m.cmp.list")
local List = require("era.m.cmp.list")

t:test("moves through items and the original input", function()
  t.assert_eq(0, List.move(-1, 2, 1), "first")
  t.assert_eq(1, List.move(0, 2, 1), "second")
  t.assert_eq(-1, List.move(1, 2, 1), "forward original")
  t.assert_eq(1, List.move(-1, 2, -1), "reverse last")
  t.assert_eq(0, List.move(1, 2, -1), "reverse first")
  t.assert_eq(-1, List.move(0, 2, -1), "reverse original")
end)

t:test("keeps empty lists unselected", function()
  t.assert_eq(-1, List.move(-1, 0, 1), "empty")
end)

t:test("resolves numeric mappings to zero-based indices", function()
  t.assert_eq(0, List.resolve(1, 9), "first")
  t.assert_eq(8, List.resolve(9, 9), "last")
  t.assert_nil(List.resolve(0, 9), "below")
  t.assert_nil(List.resolve(10, 9), "above")
end)

t:run()
