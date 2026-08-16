---@diagnostic disable: undefined-global
--- Run with: nvim -l lua/__test__/era/m/picker/view/filetree.lua

local harness = require("__test__.harness")

local t = harness.new("era.m.picker.view.filetree")

local Tree = {}
Tree.__index = Tree

function Tree.new(props)
  return { _disposed = false, _tree = props.tree, _tick_selected = 1, _tick_render_treeview = 0, statemap = {} }
end

function Tree:__health__() end

function Tree:mark_cache_treeview_dirty()
  self._tick_render_treeview = self._tick_render_treeview + 1
  return self
end

---@param inserted                      table
---@return table
---@return table
local function setup(inserted)
  local root = { uuid = "/", parent = "/" }
  local ancestor = { uuid = "/a", parent = "/" }
  local nodes = { [root.uuid] = root, [ancestor.uuid] = ancestor }
  local filetree = {
    insert_directory_absolute = function()
      return inserted
    end,
    insert_file_absolute = function()
      return inserted
    end,
    retrieve = function(_, uuid)
      return nodes[uuid]
    end,
  }

  t:patch_global("dot", { var = { nsnr = { view_filetree_matches = 1 } } })
  t:patch_global("era", { view = { Tree = Tree } })

  local FiletreeView = assert(loadfile("lua/era/m/picker/view/filetree.lua"))()
  local view = FiletreeView.new({ name = "test", tree = filetree })
  local ancestor_state = {
    nodetype = "container",
    collapsed = true,
    tick_invisible = 0,
    tick_matched = 0,
    tick_selected = 0,
    tick_selected_maximum = 0,
  }
  view.statemap[ancestor.uuid] = ancestor_state
  return view, ancestor_state
end

t:test("inserting a file preserves existing ancestor state", function()
  local view, ancestor_state = setup({ uuid = "/a/file", parent = "/a" })

  view:insert_filepath("/a/file", false)

  t.assert_true(view.statemap["/a"] == ancestor_state, "ancestor state identity")
  t.assert_true(view.statemap["/a"].collapsed, "ancestor collapsed state")
end)

t:test("inserting a directory preserves existing ancestor state", function()
  local view, ancestor_state = setup({ uuid = "/a/nested", parent = "/a" })

  view:insert_dirpath("/a/nested")

  t.assert_true(view.statemap["/a"] == ancestor_state, "ancestor state identity")
  t.assert_true(view.statemap["/a"].collapsed, "ancestor collapsed state")
end)

t:test("restore_subtree owns rebuilt state and selection ticks", function()
  local root = { uuid = "/a", children = { "/a/file" }, data = { filetype = "directory" } }
  local leaf = { uuid = "/a/file", children = {}, data = { filetype = "file" } }
  local filetree = {
    quick_traverse = function(_, _, callback)
      callback(nil, root)
      callback(nil, leaf)
    end,
  }
  t:patch_global("dot", { var = { nsnr = { view_filetree_matches = 1 } } })
  t:patch_global("era", { view = { Tree = Tree } })
  local FiletreeView = assert(loadfile("lua/era/m/picker/view/filetree.lua"))()
  local view = FiletreeView.new({ name = "test", tree = filetree })

  view:restore_subtree(root.uuid, { [leaf.uuid] = true })

  t.assert_eq("container", view.statemap[root.uuid].nodetype, "directory state")
  t.assert_eq(0, view.statemap[root.uuid].tick_selected, "unselected directory")
  t.assert_eq("leaf", view.statemap[leaf.uuid].nodetype, "file state")
  t.assert_eq(1, view.statemap[leaf.uuid].tick_selected, "selected file")
  t.assert_eq(1, view._tick_render_treeview, "tree cache invalidated")
end)

t:test("reset_filepaths restores each location once across top-level subtrees", function()
  local filepath = "/workspace/a.lua"
  local fileuuid = "file:" .. filepath
  local nodes = {
    { uuid = "/workspace", data = { filetype = "directory" } },
    { uuid = fileuuid, data = { filetype = "file" } },
    { uuid = "/archive", data = { filetype = "directory" } },
  }
  local filetree = {
    root = "/",
    reset = function() end,
    retrieve = function(_, uuid)
      return uuid == fileuuid and nodes[2] or nil
    end,
    quick_traverse = function(_, _, callback)
      for _, node in ipairs(nodes) do
        callback(nil, node)
      end
    end,
  }
  t:patch_table(table, "clear", function(target)
    for key in pairs(target) do
      target[key] = nil
    end
  end)
  t:patch_global("dot", { var = { nsnr = { view_filetree_matches = 1 } } })
  t:patch_global("era", { view = { Tree = Tree } })
  t:patch_global("stl", {
    c = { Filetree = {
      uuid = function(path)
        return "file:" .. path
      end,
    } },
    env = { PATH_SEP = "/" },
    string = {
      parse_filepath_with_location = function()
        return filepath, 12, 3, nil
      end,
    },
  })
  t:patch_global("yoz", { path = {
    is_absolute = function()
      return true
    end,
  } })
  local FiletreeView = assert(loadfile("lua/era/m/picker/view/filetree.lua"))()
  local view = FiletreeView.new({ name = "test", tree = filetree })

  view:reset_filepaths("/workspace", { filepath .. ":12:3" }, true)

  local locations = view.statemap[fileuuid].locations
  t.assert_eq(1, #locations, "location count")
  t.assert_eq(12, locations[1].lnum, "location line")
  t.assert_eq(3, locations[1].col, "location column")
end)

t:run()
