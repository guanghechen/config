---@diagnostic disable: undefined-global
--- Run with: nvim -l lua/__test__/stl/c/tree.lua

local harness = require("__test__.harness")
local bootstrap = require("__test__.bootstrap")

local t = harness.new("stl.c.tree")
bootstrap.with_runtime(t, {
  stl = {
    reporter = {
      error = function(report)
        error(report.message)
      end,
    },
    table = require("stl.table"),
  },
})
local Tree = require("stl.c.tree")

local function assert_error(callback, pattern)
  local ok, err = pcall(callback)
  t.assert_false(ok, "operation must fail")
  t.assert_true(tostring(err):find(pattern, 1, true) ~= nil, "error pattern")
end

t:test("strict API: owns explicit root, data, parent, and child order", function()
  local rootdata = { label = "root" }
  local tree = Tree.new("root", rootdata)
  t.assert_true(tree:get("root") == rootdata, "root data identity")
  t.assert_true(tree:contains("root"), "root exists")
  t.assert_nil(tree:parent("root"), "root parent is private")

  tree:insert("root", "b", { label = "b" })
  tree:insert("root", "a", { label = "a" }, 1)
  t.assert_eq("a", tree:children("root")[1], "explicit first child")
  t.assert_eq("b", tree:children("root")[2], "explicit second child")
  t.assert_eq("root", tree:parent("a"), "child parent")
end)

t:test("constructor rejects invalid ingress", function()
  assert_error(function()
    Tree.new(nil)
  end, "string or table")
end)

t:test("strict API: update and move preserve identity and reject invalid topology", function()
  local tree = Tree.new("root")
  local a = tree:insert("root", "a", { value = 1 })
  tree:insert("a", "leaf", { value = 2 })
  tree:insert("root", "side", {})

  local updated = { value = 3 }
  t.assert_true(tree:update("a", updated) == a, "update node identity")
  t.assert_true(tree:get("a") == updated, "update data identity")

  tree:move("a", "side", 1)
  t.assert_eq("side", tree:parent("a"), "moved parent")
  t.assert_eq(2, tree:retrieve("a").depth, "moved depth")
  t.assert_eq(3, tree:retrieve("leaf").depth, "descendant depth")

  tree:insert("root", "stable", {})
  assert_error(function()
    tree:move("stable", "side", 99)
  end, "out of range")
  t.assert_eq("root", tree:parent("stable"), "failed move keeps parent")
  t.assert_eq("side", tree:children("root")[1], "failed move keeps old first child")
  t.assert_eq("stable", tree:children("root")[2], "failed move keeps old second child")
  t.assert_eq("a", tree:children("side")[1], "failed move keeps new child order")

  assert_error(function()
    tree:insert("root", "a", {})
  end, "already exists")
  assert_error(function()
    tree:insert("missing", "x", {})
  end, "does not exist")
  assert_error(function()
    tree:move("side", "leaf")
  end, "cycle")
  assert_error(function()
    tree:move("root", "a")
  end, "root cannot be moved")
  assert_error(function()
    tree:remove("root")
  end, "root cannot be removed")
end)

t:test("strict API: deep move, clear, and dispose are iterative", function()
  local tree = Tree.new("root")
  local parent = "root"
  for index = 1, 10000 do
    local id = tostring(index)
    tree:insert(parent, id, {})
    parent = id
  end
  tree:insert("root", "side", {})
  tree:move("1", "side")
  t.assert_eq(10001, tree:retrieve("10000").depth, "deep moved depth")
  tree:clear()
  t.assert_true(tree:contains("root"), "clear preserves root")
  t.assert_eq(0, #tree:children("root"), "clear removes descendants")
  tree:dispose()
  t.assert_true(tree:isdisposed(), "dispose succeeds")
end)

t:test("legacy props constructor keeps sorter and upsert behavior", function()
  local tree = Tree.new({
    name = "legacy",
    node_sorter = function(left, right)
      return left.data.order < right.data.order
    end,
  })
  tree:insert(tree.root, "b", { order = 2 })
  tree:insert(tree.root, "a", { order = 1 })
  t.assert_eq("a", tree:children(tree.root)[1], "legacy sorter")
  local node = tree:insert(tree.root, "a", { order = 3 })
  t.assert_eq(3, node.data.order, "legacy upsert")
end)

t:run()
