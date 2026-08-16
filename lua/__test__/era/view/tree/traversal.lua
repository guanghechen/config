---@diagnostic disable: undefined-global
--- Run with: nvim -l lua/__test__/era/view/tree/traversal.lua

local harness = require("__test__.harness")
local bootstrap = require("__test__.bootstrap")

local t = harness.new("era.view.tree.traversal")
bootstrap.with_runtime(t, {
  stl = {
    table = require("stl.table"),
  },
})

local Tree = require("stl.c.tree")
local traversal = require("era.view.tree.traversal")

t:test("preorder: preserves forest order and explicit root semantics", function()
  local tree = Tree.new("root")
  tree:insert("root", "a", {})
  tree:insert("a", "c", {})
  tree:insert("root", "b", {})

  local visited = {}
  traversal.preorder(tree, nil, function(uuid, children)
    visited[#visited + 1] = uuid
    t.assert_true(children == tree:children(uuid), "borrowed children")
  end)
  t.assert_eq("a", visited[1], "first root")
  t.assert_eq("c", visited[2], "nested child")
  t.assert_eq("b", visited[3], "second root")

  visited = {}
  traversal.preorder(tree, "a", function(uuid)
    visited[#visited + 1] = uuid
  end)
  t.assert_eq("a", visited[1], "explicit root")
  t.assert_eq("c", visited[2], "explicit descendant")
  t.assert_eq(2, #visited, "explicit subtree size")

  traversal.preorder(tree, "missing", function()
    error("missing root must not be visited")
  end)
end)

t:test("preorder: handles depth 10000 iteratively", function()
  local tree = Tree.new("root")
  local parent = "root"
  for index = 1, 10000 do
    local uuid = tostring(index)
    tree:insert(parent, uuid, {})
    parent = uuid
  end

  local count = 0
  traversal.preorder(tree, "1", function()
    count = count + 1
  end)
  t.assert_eq(10000, count, "deep visit count")
end)

t:test("preorder: 50000-node time and heap regression ceiling", function()
  local node_count = 50000
  local fanout = 8
  local tree = Tree.new("root")
  for index = 1, node_count do
    local uuid = tostring(index)
    local parent = index == 1 and "root" or tostring(math.floor((index - 2) / fanout) + 1)
    tree:insert(parent, uuid, {})
  end

  collectgarbage("collect")
  collectgarbage("stop")
  local heap_before = collectgarbage("count")
  local started_at = vim.uv.hrtime()
  local count = 0
  traversal.preorder(tree, "1", function()
    count = count + 1
  end)
  local elapsed_ms = (vim.uv.hrtime() - started_at) / 1e6
  local heap_kib = collectgarbage("count") - heap_before
  collectgarbage("restart")

  print(string.format("BENCH era-tree-preorder 50000 time=%.3fms heap=%.1fKiB", elapsed_ms, heap_kib))
  t.assert_eq(node_count, count, "benchmark visit count")
  t.assert_true(elapsed_ms < 100, "50000-node preorder should stay below regression ceiling")
  t.assert_true(heap_kib < 4096, "50000-node preorder heap should stay below regression ceiling")
end)

t:run()
