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

---@param name                          string
---@param callback                      fun(composer: era.m.picker.FiletreeComposer)
---@param on_attached                   fun(_: era.m.picker.FiletreeComposer, rootpath: string)|nil
local function with_composer(name, callback, on_attached)
  local composer = new_composer(name, on_attached)
  local ok, err = pcall(callback, composer)
  composer:dispose()
  vim.wait(20)
  if not ok then
    error(err, 0)
  end
end

---@param composer                      era.m.picker.FiletreeComposer
---@param desc                          string
---@return fun()
local function retrieve_action(composer, desc)
  for _, keymap in ipairs(composer.result.keymaps) do
    if keymap.desc == desc then
      return keymap.callback
    end
  end
  error("Cannot retrieve action: " .. desc)
end

---@param filepath                      string
---@param filetype                      "directory"|"file"
---@return stl.c.IFiletreeNode
local function create_node(filepath, filetype)
  return {
    uuid = stl.c.Filetree.uuid(filepath),
    data = {
      filepath = filepath,
      filetype = filetype,
    },
  }
end

t:test("canonicalizes reset ingress and matches either separator", function()
  local attached_rootpath = nil ---@type string|nil
  with_composer("canonical-filetree", function(composer)
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
  end, function(_, rootpath)
    attached_rootpath = rootpath
  end)
end)

t:test("mutation actions cross only the OS boundary", function()
  with_composer("canonical-mutations", function(composer)
    local rootpath = "C:/workspace/project"
    local current_node = create_node(rootpath, "directory")
    local rootnode = current_node
    composer.__retrieve_filenode__ = function()
      return current_node
    end
    composer.__retrieve_rootnode__ = function()
      return rootnode
    end

    t:patch_table(composer.result, "get_winnr", function()
      return vim.api.nvim_get_current_win()
    end)
    t:patch_table(composer._scheduler_match, "schedule", function() end)
    t:patch_table(yoz.canonical_path, "to_os_path", function(filepath)
      return "OS<" .. filepath .. ">"
    end)
    local existing_filepath = nil ---@type string|nil
    t:patch_table(yoz.path, "is_exist", function(filepath)
      return filepath == existing_filepath
    end)
    t:patch_table(vim.ui, "select", function(_, _, callback)
      callback("Yes")
    end)

    local mkdir_calls = {} ---@type table[]
    local write_filepath = nil ---@type string|nil
    local delete_filepath = nil ---@type string|nil
    local inserted_filepath = nil ---@type string|nil
    local removed_uuid = nil ---@type string|nil
    local rename_params = nil ---@type dot.t.IRenameParams|nil
    local update_params = nil ---@type table|nil
    t:patch_table(stl.env, "mkdirs", function(filepath, isdir)
      mkdir_calls[#mkdir_calls + 1] = { filepath = filepath, isdir = isdir }
    end)
    t:patch_table(vim.fn, "writefile", function(_, filepath)
      write_filepath = filepath
    end)
    t:patch_table(vim.fn, "delete", function(filepath)
      delete_filepath = filepath
      return 0
    end)
    t:patch_table(composer._treeview, "insert_filepath", function(_, filepath)
      inserted_filepath = filepath
    end)
    t:patch_table(composer._treeview, "remove", function(_, uuid)
      removed_uuid = uuid
    end)
    t:patch_table(era.fn, "rename", function(params)
      rename_params = params
      return true
    end)
    composer.__update_tree_after_rename__ = function(_, from, to, isdir)
      update_params = { from = from, to = to, isdir = isdir }
    end

    local function submit(action_desc, value)
      local restore_input = t:patch_table(vim.ui, "input", function(_, callback)
        callback(value)
      end)
      retrieve_action(composer, action_desc)()
      restore_input()
    end

    submit("filetree: create node", [[nested\new.lua]])
    local created_filepath = rootpath .. "/nested/new.lua"
    t.assert_eq(created_filepath, inserted_filepath, "created canonical filepath")
    t.assert_eq("OS<" .. created_filepath .. ">", write_filepath, "write boundary")
    t.assert_eq("OS<" .. created_filepath .. ">", mkdir_calls[1].filepath, "create mkdir boundary")
    t.assert_false(mkdir_calls[1].isdir, "create file mkdir mode")

    local source_filepath = rootpath .. "/src/main.lua"
    current_node = create_node(source_filepath, "file")
    submit("filetree: remove node", "yes")
    t.assert_eq("OS<" .. source_filepath .. ">", delete_filepath, "delete boundary")
    t.assert_eq(current_node.uuid, removed_uuid, "removed canonical UUID")

    rename_params = nil
    update_params = nil
    existing_filepath = "OS<" .. rootpath .. "/src/renamed.lua>"
    submit("filetree: rename node", "renamed.lua")
    local renamed_filepath = rootpath .. "/src/renamed.lua"
    t.assert_eq("OS<" .. source_filepath .. ">", rename_params and rename_params.from, "rename source boundary")
    t.assert_eq("OS<" .. renamed_filepath .. ">", rename_params and rename_params.to, "rename target boundary")
    t.assert_true(rename_params and rename_params.force, "overwrite rename force")
    t.assert_eq(source_filepath, update_params and update_params.from, "rename canonical source")
    t.assert_eq(renamed_filepath, update_params and update_params.to, "rename canonical target")

    rename_params = nil
    update_params = nil
    existing_filepath = nil
    submit("filetree: move node", [[D:\archive\moved.lua]])
    local moved_filepath = "D:/archive/moved.lua"
    t.assert_eq("OS<" .. source_filepath .. ">", rename_params and rename_params.from, "move source boundary")
    t.assert_eq("OS<" .. moved_filepath .. ">", rename_params and rename_params.to, "move target boundary")
    t.assert_eq(source_filepath, update_params and update_params.from, "move canonical source")
    t.assert_eq(moved_filepath, update_params and update_params.to, "move canonical target")
  end)
end)

t:test("directory refresh canonicalizes native scan results", function()
  with_composer("canonical-directory-refresh", function(composer)
    local rootpath = "C:/workspace/project"
    local source = rootpath .. "/src/old"
    local target = stl.env.IS_WIN and "D:/archive/new" or "/archive/new"
    t:patch_table(composer._scheduler_match, "schedule", function() end)
    composer:reset_filepaths(rootpath, {
      source .. "/old.lua",
    }, false)

    local scanned = nil ---@type string|nil
    t:patch_table(yoz.canonical_path, "to_os_path", function(filepath)
      return "OS<" .. filepath .. ">"
    end)
    t:patch_table(yoz.fs, "collect_files", function(filepath)
      scanned = filepath
      return {
        files = {
          [[nested\child.lua]],
          "root.lua",
        },
      }, nil
    end)

    composer:__update_tree_after_rename__(source, target, true)

    t.assert_eq("OS<" .. target .. ">", scanned, "directory scan boundary")
    for _, filepath in ipairs({
      target .. "/nested/child.lua",
      target .. "/root.lua",
    }) do
      local node = composer._filetree:retrieve(stl.c.Filetree.uuid(filepath))
      t.assert_true(node ~= nil, "canonical scanned node: " .. filepath)
      t.assert_eq(filepath, node and node.data.filepath, "scanned filepath")
    end
  end)
end)

t:run()
