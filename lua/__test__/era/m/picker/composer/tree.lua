---@diagnostic disable: undefined-global
--- Run with: nvim -l lua/__test__/era/m/picker/composer/tree.lua

local harness = require("__test__.harness")
local bootstrap = require("__test__.bootstrap")

local t = harness.new("era.m.picker.composer.tree")
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
local TreeComposer = assert(loadfile("lua/era/m/picker/composer/tree.lua"))()

t:test("insert: owns explicit sorted child order on strict Tree", function()
  local tree = Tree.new("root")
  local composer = setmetatable({
    _disposed = false,
    _tree = tree,
    _node_sorter = function(left, right)
      if left.parent == "group" and right.parent ~= "group" then
        return true
      end
      return left.data.order < right.data.order
    end,
    fullname = "test",
  }, TreeComposer)

  composer:insert("root", "b", { order = 2 })
  composer:insert("root", "a", { order = 1 })
  t.assert_eq("a", tree:children("root")[1], "sorted first child")
  t.assert_eq("b", tree:children("root")[2], "sorted second child")

  composer:insert("root", "a", { order = 3 })
  t.assert_eq("a", tree:children("root")[1], "same-parent upsert keeps position")
  t.assert_eq(3, tree:get("a").order, "same-parent upsert updates data")

  composer:insert("root", "group", { order = 0 })
  composer:insert("group", "existing", { order = 4 })
  composer:insert("group", "a", { order = 3 })
  t.assert_eq("group", tree:parent("a"), "cross-parent upsert moves node")
  t.assert_eq("a", tree:children("group")[1], "moved node uses explicit order")
  t.assert_eq("existing", tree:children("group")[2], "existing child follows moved node")

  composer:insert("a", "nested", { order = 5 })
  local ok = pcall(composer.insert, composer, "nested", "group", { order = 99 })
  t.assert_false(ok, "cycle upsert must fail")
  t.assert_eq(0, tree:get("group").order, "failed upsert keeps old data")
  t.assert_eq("root", tree:parent("group"), "failed upsert keeps old parent")
end)

t:run()
