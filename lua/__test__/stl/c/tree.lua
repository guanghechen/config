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
  t.assert_nil(tree.retrieve, "raw nodes are not public")
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

t:test("mutation boundaries reject non-string IDs", function()
  local tree = Tree.new("root")
  local invalid_id = 1 ---@type any

  assert_error(function()
    tree:insert("root", invalid_id, {})
  end, "node id must be a string")
  assert_error(function()
    tree:insert(invalid_id, "child", {})
  end, "parent id must be a string")
  t.assert_eq(0, #tree:children("root"), "failed insert keeps topology")

  tree:insert("root", "child", {})
  assert_error(function()
    tree:update(invalid_id, {})
  end, "node id must be a string")
  assert_error(function()
    tree:move(invalid_id, "root")
  end, "node id must be a string")
  assert_error(function()
    tree:move("child", invalid_id)
  end, "parent id must be a string")
  assert_error(function()
    tree:remove(invalid_id)
  end, "node id must be a string")
  t.assert_eq("root", tree:parent("child"), "failed mutations keep topology")
end)

t:test("strict API: mutations return owner and reject invalid topology", function()
  local tree = Tree.new("root")
  t.assert_true(tree:insert("root", "a", { value = 1 }) == tree, "insert returns owner")
  tree:insert("a", "leaf", { value = 2 })
  tree:insert("root", "side", {})

  local updated = { value = 3 }
  t.assert_true(tree:update("a", updated) == tree, "update returns owner")
  t.assert_true(tree:get("a") == updated, "update data identity")

  t.assert_true(tree:move("a", "side", 1) == tree, "move returns owner")
  t.assert_eq("side", tree:parent("a"), "moved parent")
  t.assert_eq("a", tree:parent("leaf"), "moved descendant parent")

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
  t.assert_eq("side", tree:parent("1"), "deep moved parent")
  assert_error(function()
    tree:move("side", "10000")
  end, "cycle")
  tree:clear()
  t.assert_true(tree:contains("root"), "clear preserves root")
  t.assert_eq(0, #tree:children("root"), "clear removes descendants")
  tree:dispose()
  t.assert_true(tree:isdisposed(), "dispose succeeds")
end)

t:test("accessors: 50000-node time and heap regression ceiling", function()
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
  for index = 1, node_count do
    local id = ids[index]
    if tree:get(id) ~= nil and tree:parent(id) ~= nil then
      count = count + 1
    end
  end
  local elapsed_ms = (vim.uv.hrtime() - started_at) / 1e6
  local heap_kib = collectgarbage("count") - heap_before
  collectgarbage("restart")

  print(string.format("BENCH tree-accessors 50000 time=%.3fms heap=%.1fKiB", elapsed_ms, heap_kib))
  t.assert_eq(node_count, count, "benchmark accessor count")
  t.assert_true(elapsed_ms < 100, "50000-node accessors should stay below regression ceiling")
  t.assert_true(heap_kib < 4096, "50000-node accessors heap should stay below regression ceiling")
end)

t:run()
