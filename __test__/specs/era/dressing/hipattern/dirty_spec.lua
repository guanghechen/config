local harness = require("__test__.support.harness")

local t = harness.new()
local dirty = require("era.dressing.hipattern.dirty")

t:test("add keeps disjoint ranges sorted", function()
  local ranges = dirty.add({}, 20, 30)
  ranges = dirty.add(ranges, 0, 10)
  t.assert_same({ { from = 0, to = 10 }, { from = 20, to = 30 } }, ranges, "sorted ranges")
end)

t:test("add merges overlapping and adjacent ranges", function()
  local ranges = dirty.add({ { from = 0, to = 5 }, { from = 10, to = 15 } }, 5, 10)
  t.assert_same({ { from = 0, to = 15 } }, ranges, "merged ranges")
end)

t:test("transform shifts only ranges after an insertion", function()
  local ranges = dirty.transform({ { from = 2, to = 4 }, { from = 20, to = 22 } }, 10, 10, 15)
  t.assert_same({ { from = 2, to = 4 }, { from = 25, to = 27 } }, ranges, "insert transform")
end)

t:test("transform collapses deleted ranges and merges survivors", function()
  local ranges = dirty.transform({ { from = 5, to = 8 }, { from = 12, to = 16 } }, 6, 14, 7)
  t.assert_same({ { from = 5, to = 9 } }, ranges, "delete transform")
end)

t:test("take splits the requested rows off the ranges", function()
  local remaining, taken = dirty.take({ { from = 0, to = 10 }, { from = 20, to = 30 } }, 5, 25)
  t.assert_same({ { from = 0, to = 5 }, { from = 25, to = 30 } }, remaining, "remaining")
  t.assert_same({ { from = 5, to = 10 }, { from = 20, to = 25 } }, taken, "taken")
end)

t:test("take leaves ranges outside the rows and empty requests untouched", function()
  local ranges = { { from = 0, to = 10 }, { from = 20, to = 30 } } ---@type era.dressing.hipattern.dirty.IRange[]
  local remaining, taken = dirty.take(ranges, 10, 20)
  t.assert_same(ranges, remaining, "gap between ranges")
  t.assert_same({}, taken, "nothing taken")
  remaining, taken = dirty.take(ranges, 5, 5)
  t.assert_same(ranges, remaining, "empty request")
  t.assert_same({}, taken, "nothing taken from an empty request")
end)

t:run()
