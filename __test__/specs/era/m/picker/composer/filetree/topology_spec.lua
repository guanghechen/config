local harness = require("__test__.support.harness")
require("ark.bootstrap").setup()

local t = harness.new()
local picker = require("__test__.support.picker")
local treeview = require("__test__.support.treeview")

t:test("directory removal synchronizes topology state and indexes", function()
  local composer = picker.filetree_composer(t, "directory-remove-refresh")
  local root = "/workspace"
  local directory = root .. "/remove"
  local filepath = directory .. "/file.lua"
  local directory_uuid = require("era.view.result_paths").key(directory)
  local fileuuid = require("era.view.result_paths").key(filepath)
  t:patch_table(composer.result, "get_winnr", function()
    return vim.api.nvim_get_current_win()
  end)
  t:patch_table(composer._scheduler_match, "schedule", function() end)
  local Jobs = require("era.m.filetree.jobs")
  t:patch_table(Jobs, "capture", function()
    return stl.c.Future.resolve({
      data = {},
      resource = {
        info = function()
          return { directory = true }
        end,
        source = function()
          return {}
        end,
        node = function()
          return "captured"
        end,
      },
    })
  end)
  t:patch_table(Jobs, "run", function()
    return stl.c.Future.resolve({ status = {}, success = true, items = { { status = "success" } } })
  end)
  t:patch_table(vim.ui, "input", function(_, callback)
    callback("yes")
  end)
  composer:reset_filepaths(root, { filepath }, false)
  composer:__match__("file")
  treeview.publish(composer._treeview)
  ---@diagnostic disable-next-line: assign-type-mismatch
  local directory_data = composer._filetree:get(directory_uuid) ---@type era.view.result_paths.IFile
  composer.__retrieve_file__ = function()
    return directory_uuid, directory_data
  end

  picker.action(composer, "filetree: remove node")()
  t.wait_until(function()
    return not composer._file_operation_busy
  end, 5000)

  t.assert_false(composer._filetree:contains(directory_uuid), "removed directory topology")
  t.assert_false(composer._filetree:contains(fileuuid), "removed child topology")
  t.assert_nil(composer._treeview.entries[directory_uuid], "removed directory producer metadata")
  t.assert_nil(composer._treeview.entries[fileuuid], "removed child producer metadata")
  treeview.publish(composer._treeview)
  t.assert_nil(composer._treeview:retrieve(directory_uuid), "removed directory state")
  t.assert_nil(composer._treeview:retrieve(fileuuid), "removed child state")
  t.assert_eq(0, composer._uuids_order:count(), "removed order index")
  composer:__match__("file")
  t.assert_eq(0, composer._uuids_order:count(), "removed match index")
end)

t:test("directory moves preserve only producer membership without rescanning disk", function()
  local composer = picker.filetree_composer(t, "canonical-directory-refresh")
  local source, target = "/workspace/src/old", "/archive/new"
  t:patch_table(composer._scheduler_match, "schedule", function() end)
  composer:reset_filepaths("/workspace", { source .. "/old.lua", source .. "/nested/child.lua" }, false)
  treeview.publish(composer._treeview)
  composer._treeview:set_selected(require("era.view.result_paths").key(source .. "/old.lua"), true)
  treeview.publish(composer._treeview)
  t:patch_table(yoz.fs, "collect_files", function()
    error("result moves must not scan disk")
  end)
  composer:__update_tree_after_rename__(source, target .. "/")
  treeview.publish(composer._treeview)
  for _, path in ipairs({ target .. "/old.lua", target .. "/nested/child.lua" }) do
    local data = composer._filetree:get(require("era.view.result_paths").key(path))
    t.assert_eq(path, data and data.filepath)
  end
  local fileuuid = require("era.view.result_paths").key(target .. "/old.lua")
  t.assert_true(composer._treeview:isselected(fileuuid))
  treeview.publish(composer._treeview, { only_selected = true })
  t.assert_true(composer._treeview:retrieve_lnum(fileuuid) ~= nil)
end)

t:test("file refresh preserves selection at the new identity", function()
  local composer = picker.filetree_composer(t, "selected-file-refresh")
  local source = "/workspace/foo.lua"
  local target = "/workspace/foobar.lua"
  t:patch_table(composer._scheduler_match, "schedule", function() end)
  composer:reset_filepaths("/workspace", { source }, false)
  treeview.publish(composer._treeview)
  composer._treeview:set_selected(require("era.view.result_paths").key(source), true)
  treeview.publish(composer._treeview)
  composer._uuid_current = require("era.view.result_paths").key(source)
  composer:__match__("foo")

  composer:__update_tree_after_rename__(source, target)

  treeview.publish(composer._treeview)
  composer:__match__("foo")

  local source_uuid = require("era.view.result_paths").key(source)
  local target_uuid = require("era.view.result_paths").key(target)
  t.assert_true(composer._treeview:isselected(target_uuid), "renamed file selection")
  t.assert_eq(target_uuid, composer._uuid_current, "renamed current identity")
  t.assert_same({ target_uuid }, composer._uuids_order:keys(), "renamed order index")
  composer:__match__("")
  t.assert_same({ target_uuid }, composer._uuids_order:keys(), "renamed file index")
  t.assert_false(composer._uuids_order:has(source_uuid), "old file index removed")
end)

t:test("root directory refresh remaps composer indexes", function()
  local attached = nil ---@type string|nil
  local composer = picker.filetree_composer(t, "root-directory-refresh", function(_, rootpath)
    attached = rootpath
  end)
  local source = "/workspace/root"
  local target = "/archive/root"
  t:patch_table(composer._scheduler_match, "schedule", function() end)
  t:patch_table(yoz.fs, "collect_files", function()
    return { files = { "file.lua" } }, nil
  end)
  composer:reset_filepaths(source, { source .. "/file.lua" }, false)
  composer._uuid_current = require("era.view.result_paths").key(source .. "/file.lua")

  composer:__update_tree_after_rename__(source, target .. "/")

  treeview.publish(composer._treeview)

  local target_root_uuid = require("era.view.result_paths").key(target)
  local target_file_uuid = require("era.view.result_paths").key(target .. "/file.lua")
  t.assert_eq(target_root_uuid, composer._uuid_root, "renamed attached root")
  t.assert_eq(target_file_uuid, composer._uuid_current, "renamed current child")
  t.assert_same({ target_file_uuid }, composer._uuids_order:keys(), "renamed root file index")
  t.assert_eq(target, attached, "renamed attached callback")
end)

t:test("directory refresh preserves an empty destination", function()
  local composer = picker.filetree_composer(t, "empty-directory-refresh")
  local source = "/workspace/empty"
  local target = "/archive/empty"
  t:patch_table(composer._scheduler_match, "schedule", function() end)
  t:patch_table(yoz.fs, "collect_files", function()
    return { files = {} }, nil
  end)
  composer._treeview:insert_dirpath(source)

  composer:__update_tree_after_rename__(source, target .. "/")

  treeview.publish(composer._treeview)

  local target_uuid = require("era.view.result_paths").key(target)
  local data = composer._filetree:get(target_uuid) ---@type era.view.result_paths.IFile|nil
  local state = composer._treeview:retrieve(target_uuid) ---@type era.view.result_tree.IEntry|nil
  t.assert_eq(target, data and data.filepath, "empty destination data")
  t.assert_eq("container", state and state.nodetype, "empty destination state")
end)

t:test("directory overwrite removes the replaced target subtree", function()
  local composer = picker.filetree_composer(t, "directory-overwrite-refresh")
  local source = "/workspace/source"
  local target = "/archive/target"
  local source_file = source .. "/moved.lua"
  local target_file = target .. "/moved.lua"
  local stale_file = target .. "/stale.lua"
  t:patch_table(composer._scheduler_match, "schedule", function() end)
  t:patch_table(yoz.fs, "collect_files", function()
    return { files = { "moved.lua" } }, nil
  end)
  composer:reset_filepaths("/workspace", { source_file, stale_file }, false)
  treeview.publish(composer._treeview)
  composer._treeview:set_selected(require("era.view.result_paths").key(source_file), true)
  treeview.publish(composer._treeview)
  t.assert_true(
    composer._treeview:isselected(require("era.view.result_paths").key(source_file)),
    "publication includes queued selection"
  )
  composer._treeview:set_selected(require("era.view.result_paths").key(stale_file), true)
  treeview.publish(composer._treeview)

  composer:__update_tree_after_rename__(source, target .. "/")

  treeview.publish(composer._treeview)

  local target_uuid = require("era.view.result_paths").key(target_file)
  local stale_uuid = require("era.view.result_paths").key(stale_file)
  t.assert_true(composer._filetree:contains(target_uuid), "overwritten target file")
  t.assert_true(composer._treeview:isselected(target_uuid), "source selection remapped")
  t.assert_false(composer._filetree:contains(stale_uuid), "stale target topology removed")
  t.assert_nil(composer._treeview:retrieve(stale_uuid), "stale target state removed")
  t.assert_false(composer._treeview:isselected(stale_uuid), "stale target selection removed")
end)

t:test("directory moves retain location metadata and native selection without disk scans", function()
  local composer = picker.filetree_composer(t, "location-move")
  local source, target = "/workspace/source", "/archive/target"
  local key = require("era.view.result_paths").key(source .. "/known.lua")
  local next_key = require("era.view.result_paths").key(target .. "/known.lua")
  t:patch_table(composer._scheduler_match, "schedule", function() end)
  t:patch_table(yoz.fs, "collect_files", function()
    error("unexpected directory scan")
  end)
  composer:reset_filepaths("/workspace", { source .. "/known.lua" }, false)
  composer._treeview:add_location(key, { locationuuid = "location", lnum = 7, col = 3, col_end = 5, text = "match" })
  treeview.publish(composer._treeview)
  composer._treeview:set_selected("location", true)
  treeview.publish(composer._treeview)
  local old = composer._treeview:frame():source():id("location")
  composer:__update_tree_after_rename__(source, target .. "/")
  treeview.publish(composer._treeview)
  local location = composer._treeview:retrieve("location")
  t.assert_eq(next_key, location.leafuuid)
  t.assert_eq(7, location.lnum)
  t.assert_eq("match", location.text)
  t.assert_eq(old, composer._treeview:frame():source():id("location"))
  t.assert_true(composer._treeview:isselected("location"))
  t.assert_eq(target .. "/known.lua", composer._treeview:data("location").filepath)
end)

t:test("rename restores the native cursor to the new file identity", function()
  local composer = picker.filetree_composer(t, "rename-cursor")
  composer:reset_filepaths("/workspace", { "aaa.lua", "bbb.lua", "zzz.lua" }, false)
  picker.show_result(composer, 60, 8)
  local tree = composer._treeview
  treeview.await(tree:ready())
  composer.result:set_lnum_current(2)
  treeview.await(tree:ready())
  composer:__update_tree_after_rename__("/workspace/bbb.lua", "/workspace/renamed.lua")
  treeview.await(composer.result.draw())
  treeview.await(tree:ready())
  local cursor = vim.api.nvim_win_get_cursor(composer.result:get_winnr())[1]
  t.assert_eq("/workspace/renamed.lua", tree:data(tree:retrieve_uuid(cursor)).filepath)
  t.assert_eq(cursor, composer.result.lnum_current:snapshot())
end)

t:run()
