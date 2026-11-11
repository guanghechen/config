local harness = require("__test__.support.harness")
require("ark.bootstrap").setup()

local t = harness.new()
local picker = require("__test__.support.picker")

t:test("canonicalizes reset ingress and matches canonical root-relative paths", function()
  local attached_rootpath = nil ---@type string|nil
  local composer = picker.filetree_composer(t, "canonical-filetree", function(_, rootpath)
    attached_rootpath = rootpath
  end)
  composer:reset_filepaths([[C:\workspace\project\]], {
    [[src\main.lua]],
    "src/lib/util.lua",
    "space dir/项目/#notes.lua",
  }, false)

  local canonical_rootpath = "C:/workspace/project"
  t.assert_eq(canonical_rootpath, attached_rootpath, "attached rootpath")
  t.assert_eq(3, composer._uuids_order:count(), "canonical cwd collection")

  composer:__match__("src/lib")
  t.assert_eq(1, composer._uuids_order:count(), "canonical separator match count")
  local data = composer._filetree:get(composer._uuids_order:keys()[1]) ---@type era.view.result_paths.IFile|nil
  t.assert_true(data ~= nil, "matched data")
  t.assert_eq(canonical_rootpath .. "/src/lib/util.lua", data and data.filepath, "matched canonical filepath")

  -- Paths match relative to the root, and a backslash is literal rather than a separator.
  composer:__match__("^src/")
  t.assert_eq(2, composer._uuids_order:count(), "root-relative prefix")
  composer:__match__([[src\lib]])
  t.assert_eq(0, composer._uuids_order:count(), "backslash query match count")
end)

t:test("identical path refreshes reuse the producer and observe later path mutations", function()
  local composer = picker.filetree_composer(t, "stable-paths")
  local paths = { "src/one.lua", "src/two.lua" }
  composer:reset_filepaths("/workspace", paths, false)
  local source = composer._filetree
  local one = require("era.view.result_paths").key("/workspace/src/one.lua")
  local revision, data = source.revision, source:get(one)
  composer:reset_filepaths("/workspace", paths, false)
  t.assert_eq(revision, source.revision, "equal inputs do not rebuild path topology")
  t.assert_true(data == source:get(one))
  source:remove(one)
  composer:reset_filepaths("/workspace", paths, false)
  t.assert_true(source:contains(one), "a producer mutation invalidates reuse")
  paths[1] = "src/three.lua"
  composer:reset_filepaths("/workspace", paths, false)
  t.assert_false(source:contains(one), "mutating the caller's array changes membership")
  t.assert_true(source:contains(require("era.view.result_paths").key("/workspace/src/three.lua")))
end)

t:run()
