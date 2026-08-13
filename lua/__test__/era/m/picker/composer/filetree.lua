---@diagnostic disable: invisible
--- Run with: nvim -l lua/__test__/era/m/picker/composer/filetree.lua

local harness = require("__test__.harness")
require("ark.bootstrap").setup()

local t = harness.new("era.m.picker.composer.filetree")

---@param value                         unknown
---@return stl.c.Observable
local function observable(value)
  return stl.c.Observable.from_value(value)
end

---@param name                          string
---@param on_attached                   fun(_: era.m.picker.FiletreeComposer, rootpath: string)|nil
---@return era.m.picker.FiletreeComposer
local function new_composer(name, on_attached)
  return era.m.picker.FiletreeComposer.new({
    name = name,
    permanent = false,
    preview = false,
    title = "filetree test",
    search_pattern = observable(""),
    flag_foldempty = observable(false),
    flag_fuzzy = observable(false),
    flag_regex = observable(false),
    flag_case_sensitive = observable(true),
    flag_selected = observable(false),
    flag_viewtype = observable("tree"),
    on_attached = on_attached,
  })
end

t:test("canonicalizes reset ingress and matches either separator", function()
  local attached_rootpath = nil ---@type string|nil
  local composer = new_composer("canonical-filetree", function(_, rootpath)
    attached_rootpath = rootpath
  end)
  local ok, err = pcall(function()
    composer:reset_filepaths([[C:\workspace\project\]], {
      [[src\main.lua]],
      "src/lib/util.lua",
      "space dir/项目/#notes.lua",
    }, false)

    local canonical_rootpath = "C:/workspace/project"
    t.assert_eq(canonical_rootpath, attached_rootpath, "attached rootpath")
    t.assert_eq(3, #composer._uuids_order, "canonical cwd collection")

    local restore_path_sep = t:patch_table(stl.env, "PATH_SEP", "\\")
    composer:__match__([[src\lib]])
    restore_path_sep()

    t.assert_eq(1, #composer._uuids_order, "backslash query match count")
    local node = composer._filetree:retrieve(composer._uuids_order[1]) ---@type stl.c.IFiletreeNode|nil
    t.assert_true(node ~= nil, "matched node")
    t.assert_eq(canonical_rootpath .. "/src/lib/util.lua", node and node.data.filepath, "matched canonical filepath")
  end)

  composer:dispose()
  vim.wait(20)
  if not ok then
    error(err, 0)
  end
end)

t:run()
