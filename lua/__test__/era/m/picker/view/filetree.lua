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
    root = root.uuid,
    insert_directory_absolute = function()
      return inserted
    end,
    insert_file_absolute = function()
      return inserted
    end,
    parent = function(_, uuid)
      local node = nodes[uuid] or inserted
      return node.uuid == root.uuid and nil or node.parent
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
  local nodes = { [root.uuid] = root, [leaf.uuid] = leaf }
  local filetree = {
    root = "/",
    contains = function(_, uuid)
      return nodes[uuid] ~= nil
    end,
    children = function(_, uuid)
      return nodes[uuid] and nodes[uuid].children or nil
    end,
    get = function(_, uuid)
      return nodes[uuid] and nodes[uuid].data or nil
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

  local visited = 0
  view:traverse_filenode(root.uuid, function(uuid, data, nodestate)
    visited = visited + 1
    t.assert_eq(leaf.uuid, uuid, "visited file uuid")
    t.assert_true(data == leaf.data, "visited file data")
    t.assert_true(nodestate == view.statemap[leaf.uuid], "visited file state")
  end)
  t.assert_eq(1, visited, "visited file count")
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
    contains = function(_, uuid)
      for _, node in ipairs(nodes) do
        if node.uuid == uuid then
          return true
        end
      end
      return false
    end,
    children = function(_, uuid)
      if uuid == "/" then
        return { nodes[1].uuid, nodes[3].uuid }
      end
      if uuid == nodes[1].uuid then
        return { fileuuid }
      end
      return {}
    end,
    get = function(_, uuid)
      for _, node in ipairs(nodes) do
        if node.uuid == uuid then
          return node.data
        end
      end
      return nil
    end,
    reset = function() end,
    retrieve = function(_, uuid)
      return uuid == fileuuid and nodes[2] or nil
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

t:test("match reads leaf data and marks ancestors without matching the root", function()
  local rootuuid = "/"
  local parentuuid = "/workspace"
  local leafuuid = "/workspace/a.lua"
  local nodes = {
    { uuid = parentuuid, data = { filetype = "directory" } },
    { uuid = leafuuid, data = { filetype = "file", filepath = leafuuid, filepath_lower = leafuuid } },
  }
  local parents = { [parentuuid] = rootuuid, [leafuuid] = parentuuid }
  local filetree = {
    root = rootuuid,
    children = function(_, uuid)
      if uuid == rootuuid then
        return { parentuuid }
      end
      if uuid == parentuuid then
        return { leafuuid }
      end
      return {}
    end,
    get = function(_, uuid)
      return uuid == leafuuid and nodes[2].data or nil
    end,
    parent = function(_, uuid)
      return parents[uuid]
    end,
  }
  t:patch_global("dot", { var = { nsnr = { view_filetree_matches = 1 } } })
  t:patch_global("era", { view = { Tree = Tree } })
  t:patch_global("stl", {
    reporter = {
      error = function(report)
        error(report.message or report.subject)
      end,
    },
    table = { truncate_inline = function() end },
  })
  t:patch_global("yoz", {
    search = {
      search_in_lines = function(params)
        t.assert_eq(leafuuid, params.lines[1], "searched filepath")
        return { lines = { { lnum = 1, score = 1, matches = {} } } }, nil
      end,
    },
  })
  local FiletreeView = assert(loadfile("lua/era/m/picker/view/filetree.lua"))()
  local view = FiletreeView.new({ name = "test", tree = filetree })
  view.statemap[parentuuid] = {
    nodetype = "container",
    collapsed = false,
    tick_invisible = 0,
    tick_matched = 0,
    tick_selected = 0,
    tick_selected_maximum = 0,
  }
  view.statemap[leafuuid] = {
    nodetype = "leaf",
    collapsed = false,
    tick_invisible = 0,
    tick_matched = 0,
    tick_selected = 0,
  }

  local matched = view:match({
    rootuuid = rootuuid,
    pattern = "a",
    case_sensitive = true,
    fuzzy = false,
    regex = false,
  })

  t.assert_eq(leafuuid, matched[1], "matched leaf")
  t.assert_eq(view._tick_matched, view.statemap[leafuuid].tick_matched, "leaf matched tick")
  t.assert_eq(view._tick_matched, view.statemap[parentuuid].tick_matched, "ancestor matched tick")
  t.assert_nil(view.statemap[rootuuid], "synthetic root state")
end)

t:run()
