---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.specs.era.m.picker.composer.tree" ---@type string

require("ark.bootstrap").setup()
local t = require("__test__.support.harness").new("era.m.picker.composer.tree")
local native = require("__test__.support.result_tree")
local Source = require("era.view.result_source")
local View = require("era.view.result_tree")
local Composer = require("era.m.picker.composer.tree")

---@return era.m.picker.TreeComposer
local function fixture()
  local source = Source.new("root", { name = "root" })
  local view = View.new({
    name = "symbols",
    tree = source,
    present = function(_, data)
      return { label = data.name }
    end,
  })
  local composer = setmetatable({
    fullname = "symbols",
    _disposed = false,
    _tree = source,
    _treeview = view,
    _node_sorter = function(a, b)
      return a.name < b.name
    end,
    _scheduler_match = { schedule = function() end },
    _on_attached = function() end,
  }, Composer)
  t:defer(function()
    view:dispose()
  end)
  return composer
end

---@param composer                      era.m.picker.TreeComposer
---@return nil
local function publish(composer)
  composer._tree:walk(nil, function(key, data)
    composer._treeview:insert(key, {
      nodetype = #composer._tree:children(key) > 0 and "container" or "leaf",
      text = data.name,
    })
  end)
  native.publish(composer._treeview)
end

t:test("symbol insertion preserves source order in native rows", function()
  local composer = fixture()
  composer:insert("root", "second", { name = "z" })
  composer:insert("root", "first", { name = "a" })
  publish(composer)
  t.assert_eq("first", composer._treeview:retrieve_uuid(1))
  t.assert_eq("second", composer._treeview:retrieve_uuid(2))
end)

t:test("reparenting a symbol preserves its native selection", function()
  local composer = fixture()
  composer:insert("root", "left", { name = "left" })
  composer:insert("root", "right", { name = "right" })
  composer:insert("left", "leaf", { name = "leaf" })
  publish(composer)
  composer._treeview:toggle_select("leaf", true, false)
  native.publish(composer._treeview)
  composer:insert("right", "leaf", { name = "leaf" })
  publish(composer)
  t.assert_true(composer._treeview:isselected("leaf"))
  local frame = composer._treeview:frame()
  local leaf = frame:source():id("leaf")
  t.assert_eq(frame:source():id("right"), frame:node(leaf).parent)
end)

t:test("attach rejects unknown roots and publishes known symbol roots", function()
  local composer = fixture()
  local errors = {}
  t:patch_table(stl.reporter, "error", function(value)
    errors[#errors + 1] = value
  end)
  composer:attach("absent")
  t.assert_eq(1, #errors)
  t.assert_nil(composer._uuid_root)
  composer:insert("root", "scope", { name = "scope" })
  composer:insert("scope", "symbol", { name = "symbol" })
  publish(composer)
  composer:attach("scope")
  native.publish(composer._treeview, { rootuuid = composer._uuid_root })
  t.assert_eq("symbol", composer._treeview:retrieve_uuid(1))
end)

t:run()
