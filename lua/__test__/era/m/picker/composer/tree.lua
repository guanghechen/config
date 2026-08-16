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
      return left.order < right.order
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

t:test("attach: validates roots through strict topology accessors", function()
  local tree = Tree.new("root")
  tree:insert("root", "child", {})
  local dirty_count = 0
  local schedule_count = 0
  local attached_uuid ---@type string|nil
  local composer = setmetatable({
    _disposed = false,
    _tree = tree,
    _treeview = {
      mark_cache_listview_dirty = function()
        dirty_count = dirty_count + 1
      end,
    },
    _scheduler_match = {
      schedule = function()
        schedule_count = schedule_count + 1
      end,
    },
    _on_attached = function(_, uuid)
      attached_uuid = uuid
    end,
    _uuid_root = "root",
  }, TreeComposer)

  composer:attach("child")

  t.assert_eq("child", composer._uuid_root, "attached root")
  t.assert_eq("child", attached_uuid, "attached callback")
  t.assert_eq(1, dirty_count, "view dirty count")
  t.assert_eq(1, schedule_count, "match schedule count")
end)

t:test("toggle: resolves state and children through strict accessors", function()
  local tree = Tree.new("root")
  tree:insert("root", "leaf", {})
  tree:insert("leaf", "child", {})
  local collapse_uuid ---@type string|nil
  local dirty_count = 0
  local composer = setmetatable({
    _tree = tree,
    _treeview = {
      retrieve = function(_, uuid)
        if uuid == "leaf" then
          return { nodetype = "leaf" }
        end
        return { nodetype = "container" }
      end,
      collapse = function(_, uuid)
        collapse_uuid = uuid
      end,
    },
    _composer = {
      mark_result_dirty = function()
        dirty_count = dirty_count + 1
      end,
    },
    _retriever = {
      retrieve_lnum = function()
        return nil
      end,
    },
  }, TreeComposer)

  composer:__toggle_node__("leaf", false, false)
  local root_lnum, root_parent = composer:__retrieve_lnum_parent__("root")

  t.assert_eq("leaf", collapse_uuid, "collapsed topology node")
  t.assert_eq(1, dirty_count, "result dirty count")
  t.assert_nil(root_lnum, "root parent line")
  t.assert_nil(root_parent, "root parent uuid")
end)

t:run()
