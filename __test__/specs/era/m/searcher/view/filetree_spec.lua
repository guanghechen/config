require("ark.bootstrap").setup()
local t = require("__test__.support.harness").new()
local treeview = require("__test__.support.treeview")
local Paths = require("era.view.result_paths")
local Files = require("era.m.searcher.view.filetree")

---@param count                         integer
---@return era.m.searcher.FiletreeView
---@return string
local function fixture(count)
  local tree = Files.new({ name = "search locations", tree = Paths.new() })
  t:defer(function()
    tree:dispose()
  end)
  tree:reset_filepaths("/search-locations", { "matches.lua" })
  local key = Paths.key("/search-locations/matches.lua")
  for index = 1, count do
    tree:add_location(key, { locationuuid = "match:" .. index, lnum = index, col = 1, text = "match" })
  end
  return tree, key
end

t:test("removing visible matches preserves hidden order and the published metadata", function()
  local tree, key = fixture(5)
  tree:mark_node_invisible("match:2")
  tree:mark_node_invisible("match:4")
  treeview.publish(tree)
  local published = tree:retrieve(key)
  tree:remove_visible_locations(published)
  t.assert_eq(5, #published.locations, "the displayed snapshot remains immutable until publication")
  t.assert_eq(5, #tree:retrieve(key).locations)
  t.assert_eq(2, #tree.entries[key].locations)
  t.assert_eq("match:2", tree.entries[key].locations[1].locationuuid)
  t.assert_eq("match:4", tree.entries[key].locations[2].locationuuid)
  t.assert_nil(tree.entries["match:1"])
  t.assert_nil(tree.entries["match:3"])
  t.assert_nil(tree.entries["match:5"])
  treeview.publish(tree)
  t.assert_eq(2, #tree:retrieve(key).locations)
  tree:reset_hidden()
  tree:remove_visible_locations(tree:retrieve(key))
  treeview.publish(tree)
  t.assert_eq(0, #tree:retrieve(key).locations)
  t.assert_nil(tree.entries["match:2"])
  t.assert_nil(tree.entries["match:4"])
end)

t:test("clearing a dense file keeps only its excluded match", function()
  local tree, key = fixture(10000)
  tree:mark_node_invisible("match:10000")
  tree:remove_visible_locations(tree.entries[key])
  t.assert_eq(1, #tree.entries[key].locations)
  t.assert_eq("match:10000", tree.entries[key].locations[1].locationuuid)
end)

t:run()
