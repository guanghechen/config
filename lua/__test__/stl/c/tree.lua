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
  end, "root must be a string")
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

t:test("quick_traverse: preserves preorder, conditional pruning, and root context", function()
  local tree = Tree.new("root")
  tree:insert("root", "a", {})
  tree:insert("a", "b", {})
  tree:insert("b", "d", {})
  tree:insert("a", "c", {})
  local visited = {}
  tree:quick_traverse("a", function(ctx, node, depth)
    visited[#visited + 1] = string.format("%s:%d:%s", node.uuid, depth, ctx.rootnode.uuid)
  end, function(_, node)
    return node.uuid == "b" and "goodnode" or "goodroot"
  end)
  t.assert_eq("a:1:a", visited[1], "root visit")
  t.assert_eq("b:2:a", visited[2], "goodnode visit")
  t.assert_eq("c:2:a", visited[3], "pruned sibling order")
  t.assert_eq(3, #visited, "pruned descendant count")
end)

t:test("quick_traverse: handles depth 10000 iteratively", function()
  local tree = Tree.new("root")
  local parent = "root"
  for index = 1, 10000 do
    local id = tostring(index)
    tree:insert(parent, id, {})
    parent = id
  end
  local count = 0
  local last_depth = 0
  tree:quick_traverse("1", function(_, _, depth)
    count = count + 1
    last_depth = depth
  end)
  t.assert_eq(10000, count, "deep visit count")
  t.assert_eq(10000, last_depth, "deep relative depth")
end)

t:test("quick_traverse: snapshots child count after parent callback", function()
  local tree = Tree.new("root")
  tree:insert("root", "a", {})
  tree:insert("a", "b", {})
  local visited = {}
  tree:quick_traverse("a", function(_, node)
    visited[#visited + 1] = node.uuid
    if node.uuid == "b" then
      tree:insert("a", "late", {})
    end
  end)
  t.assert_eq(2, #visited, "late sibling is outside traversal snapshot")
  t.assert_eq("b", visited[2], "existing child visited")
  t.assert_true(tree:contains("late"), "late sibling was inserted")
end)

t:test("hot paths: 50000-node time and heap regression ceiling", function()
  local node_count = 50000
  local fanout = 8
  local tree = Tree.new("root")
  local ids = {}
  for index = 1, node_count do
    local id = tostring(index)
    ids[index] = id
    local parent = index == 1 and "root" or tostring(math.floor((index - 2) / fanout) + 1)
    tree:insert(parent, id, {})
  end

  collectgarbage("collect")
  collectgarbage("stop")
  local heap_before = collectgarbage("count")
  local started_at = vim.uv.hrtime()
  local count = 0
  tree:quick_traverse("1", function()
    count = count + 1
  end)
  local elapsed_ms = (vim.uv.hrtime() - started_at) / 1e6
  local heap_kib = collectgarbage("count") - heap_before
  collectgarbage("restart")

  print(string.format("BENCH tree-quick-traverse 50000 time=%.3fms heap=%.1fKiB", elapsed_ms, heap_kib))
  t.assert_eq(node_count, count, "benchmark visit count")
  t.assert_true(elapsed_ms < 100, "50000-node traversal should stay below regression ceiling")
  t.assert_true(heap_kib < 4096, "50000-node traversal heap should stay below regression ceiling")

  collectgarbage("collect")
  collectgarbage("stop")
  heap_before = collectgarbage("count")
  started_at = vim.uv.hrtime()
  count = 0
  for index = 1, node_count do
    local id = ids[index]
    if tree:get(id) ~= nil and tree:parent(id) ~= nil then
      count = count + 1
    end
  end
  elapsed_ms = (vim.uv.hrtime() - started_at) / 1e6
  heap_kib = collectgarbage("count") - heap_before
  collectgarbage("restart")

  print(string.format("BENCH tree-accessors 50000 time=%.3fms heap=%.1fKiB", elapsed_ms, heap_kib))
  t.assert_eq(node_count, count, "benchmark accessor count")
  t.assert_true(elapsed_ms < 100, "50000-node accessors should stay below regression ceiling")
  t.assert_true(heap_kib < 4096, "50000-node accessors heap should stay below regression ceiling")
end)

t:run()
