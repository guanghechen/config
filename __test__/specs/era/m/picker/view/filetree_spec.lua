---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.specs.era.m.picker.view.filetree" ---@type string

require("ark.bootstrap").setup()
local t = require("__test__.support.harness").new("era.m.picker.view.filetree")
local native = require("__test__.support.result_tree")
local Paths = require("era.view.result_paths")
local Files = require("era.view.result_files")

---@return era.m.picker.FiletreeView
local function fixture()
  local view = Files.new({ name = "file result test", tree = Paths.new() })
  t:defer(function()
    view:dispose()
  end)
  view:reset_filepaths("/workspace", { "dir/one.lua", "two.lua" }, false)
  native.publish(view, { rootuuid = Paths.key("/workspace") })
  return view
end

for _, directory in ipairs({ false, true }) do
  t:test("inserting a " .. (directory and "directory" or "file") .. " preserves native ancestor state", function()
    local view = fixture()
    local key = Paths.key("/workspace/dir")
    view:collapse(key, "collapse", false)
    view:toggle_select(key, true, true)
    native.publish(view)
    if directory then
      view:insert_dirpath("/workspace/dir/new")
    else
      view:insert_filepath("/workspace/dir/new.lua", false)
    end
    native.publish(view)
    t.assert_true(view:retrieve(key).collapsed)
    t.assert_true(view:isselected(key))
    local child = Paths.key(directory and "/workspace/dir/new" or "/workspace/dir/new.lua")
    t.assert_true(view:isselected(child), "new descendants inherit the native subtree selection")
  end)
end

t:test("restored results preserve selection after a file identity changes", function()
  local view = fixture()
  local key = Paths.key("/workspace/dir/renamed.lua")
  view.source:remove(Paths.key("/workspace/dir/one.lua"))
  view.source:insert_file_absolute("/workspace/dir/renamed.lua")
  view:restore_subtree(Paths.key("/workspace/dir"), { [key] = true })
  native.publish(view, { only_selected = true })
  t.assert_true(view:isselected(key))
  t.assert_true(view:retrieve_lnum(key) ~= nil)
end)

t:test("reset restores native location identities and selection", function()
  local view = fixture()
  view:reset_filepaths("/workspace", { "dir/one.lua:4:2", "dir/one.lua:9:3" }, true)
  native.publish(view)
  local key = Paths.key("/workspace/dir/one.lua")
  local before = view:retrieve(key).locations
  t.assert_eq(2, #before)
  view:toggle_select(key, true, true)
  native.publish(view)
  view:reset_filepaths("/workspace", { "dir/one.lua:4:2", "dir/one.lua:9:3" }, true)
  native.publish(view, { mode = "list", only_selected = true })
  t.assert_true(view:isselected(key))
  t.assert_true(view:isselected(before[1].locationuuid))
  t.assert_eq(3, view:linecount(), "List membership excludes directory ancestors")
end)

t:test("search membership is projected through native ancestors", function()
  local view = fixture()
  local keys = view:match({
    rootuuid = Paths.key("/workspace"),
    pattern = "one.lua",
    fuzzy = false,
    regex = false,
    case_sensitive = false,
  })
  t.assert_eq(1, #keys)
  t.assert_eq(Paths.key("/workspace/dir/one.lua"), keys[1])
  native.publish(view, { rootuuid = Paths.key("/workspace"), only_matched = true, orders = keys })
  t.assert_eq(2, view:linecount())
  t.assert_eq(Paths.key("/workspace/dir"), view:retrieve_uuid(1))
  t.assert_eq(keys[1], view:retrieve_uuid(2))
end)

t:test("a plain file is never treated as a collapsed branch", function()
  local view = fixture()
  t.assert_false(view:retrieve(Paths.key("/workspace/two.lua")).collapsed)
  view:add_location(Paths.key("/workspace/two.lua"), { lnum = 3, col = 1 })
  native.publish(view)
  local location = view:retrieve(Paths.key("/workspace/two.lua")).locations[1]
  t.assert_eq("/workspace/two.lua", view:data(location.locationuuid).filepath)
end)

t:test("file imports defer icon detection until a viewport needs the file", function()
  local calls = 0
  t:patch_table(stl.fileicon, "get_file_icon", function()
    calls = calls + 1
    return "F", "Normal"
  end)
  local view = fixture()
  t.assert_eq(0, calls)
  local key = Paths.key("/workspace/two.lua")
  local frame = view:frame()
  t.assert_eq("two.lua", frame:node(frame:source():id(key)).fields.file_icon)
end)

t:test("Tree uses directories-first name order while List keeps explicit ranking", function()
  local view = fixture()
  view:reset_filepaths("/workspace", { "z.lua", "src/b.lua", "src/a.lua", "a.lua", "aaa/x.lua" }, false)
  local root = Paths.key("/workspace")
  native.publish(view, { rootuuid = root })
  local paths = {}
  for row = 1, view:linecount() do
    paths[#paths + 1] = view:data(view:retrieve_uuid(row)).filepath
  end
  local expected = {
    "/workspace/aaa",
    "/workspace/aaa/x.lua",
    "/workspace/src",
    "/workspace/src/a.lua",
    "/workspace/src/b.lua",
    "/workspace/a.lua",
    "/workspace/z.lua",
  }
  t.assert_true(vim.deep_equal(expected, paths), vim.inspect(paths))
  view:insert_filepath("/workspace/src/0.lua", false)
  native.publish(view, { rootuuid = root })
  t.assert_eq(Paths.key("/workspace/src/0.lua"), view:retrieve_uuid(4))
  local orders = { Paths.key("/workspace/z.lua"), Paths.key("/workspace/src/a.lua") }
  native.publish(view, { mode = "list", rootuuid = root, orders = orders })
  t.assert_eq(orders[1], view:retrieve_uuid(1))
  t.assert_eq(orders[2], view:retrieve_uuid(2))
end)

t:run()
