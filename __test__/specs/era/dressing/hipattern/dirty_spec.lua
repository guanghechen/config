local harness = require("__test__.support.harness")

local t = harness.new()
local dirty = require("era.dressing.hipattern.dirty")

---@param ranges                        era.dressing.hipattern.dirty.IRange[]
---@return string
local function inspect(ranges)
  return vim.inspect(ranges)
end

t:test("add keeps disjoint ranges sorted", function()
  local ranges = dirty.add({}, 20, 30)
  ranges = dirty.add(ranges, 0, 10)
  t.assert_eq(inspect({ { from = 0, to = 10 }, { from = 20, to = 30 } }), inspect(ranges), "sorted ranges")
end)

t:test("add merges overlapping and adjacent ranges", function()
  local ranges = dirty.add({ { from = 0, to = 5 }, { from = 10, to = 15 } }, 5, 10)
  t.assert_eq(inspect({ { from = 0, to = 15 } }), inspect(ranges), "merged ranges")
end)

t:test("transform shifts only ranges after an insertion", function()
  local ranges = dirty.transform({ { from = 2, to = 4 }, { from = 20, to = 22 } }, 10, 10, 15)
  t.assert_eq(inspect({ { from = 2, to = 4 }, { from = 25, to = 27 } }), inspect(ranges), "insert transform")
end)

t:test("transform collapses deleted ranges and merges survivors", function()
  local ranges = dirty.transform({ { from = 5, to = 8 }, { from = 12, to = 16 } }, 6, 14, 7)
  t.assert_eq(inspect({ { from = 5, to = 9 } }), inspect(ranges), "delete transform")
end)

t:test("take splits the requested rows off the ranges", function()
  local remaining, taken = dirty.take({ { from = 0, to = 10 }, { from = 20, to = 30 } }, 5, 25)
  t.assert_eq(inspect({ { from = 0, to = 5 }, { from = 25, to = 30 } }), inspect(remaining), "remaining")
  t.assert_eq(inspect({ { from = 5, to = 10 }, { from = 20, to = 25 } }), inspect(taken), "taken")
end)

t:test("take leaves ranges outside the rows and empty requests untouched", function()
  local ranges = { { from = 0, to = 10 }, { from = 20, to = 30 } } ---@type era.dressing.hipattern.dirty.IRange[]
  local remaining, taken = dirty.take(ranges, 10, 20)
  t.assert_eq(inspect(ranges), inspect(remaining), "gap between ranges")
  t.assert_eq(inspect({}), inspect(taken), "nothing taken")
  remaining, taken = dirty.take(ranges, 5, 5)
  t.assert_eq(inspect(ranges), inspect(remaining), "empty request")
  t.assert_eq(inspect({}), inspect(taken), "nothing taken from an empty request")
end)

t:run()
