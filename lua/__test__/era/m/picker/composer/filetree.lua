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
---@param on_confirm                    era.m.picker.composer.filetree.IOnConfirm|nil
---@param on_preview_rendered           era.m.picker.composer.filetree.IOnPreviewRendered|nil
---@return era.m.picker.FiletreeComposer
local function new_composer(name, on_attached, on_confirm, on_preview_rendered)
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
    on_confirm = on_confirm,
    on_preview_rendered = on_preview_rendered,
  })
end

---@param name                          string
---@param callback                      fun(composer: era.m.picker.FiletreeComposer)
---@param on_attached                   fun(_: era.m.picker.FiletreeComposer, rootpath: string)|nil
---@param on_confirm                    era.m.picker.composer.filetree.IOnConfirm|nil
---@param on_preview_rendered           era.m.picker.composer.filetree.IOnPreviewRendered|nil
local function with_composer(name, callback, on_attached, on_confirm, on_preview_rendered)
  local composer = new_composer(name, on_attached, on_confirm, on_preview_rendered)
  local ok, err = pcall(callback, composer)
  composer:dispose()
  vim.wait(20)
  if not ok then
    error(err, 0)
  end
end

t:test("preview callback receives the resolved file data", function()
  local basic_props = nil ---@type era.m.picker.composer.basic.IProps|nil
  local original_new = era.m.picker.BasicComposer.new
  t:patch_table(era.m.picker.BasicComposer, "new", function(props)
    basic_props = props
    return original_new(props)
  end)

  local expected = {
    filepath = "/workspace/main.lua",
    filetype = "file",
  }
  local actual = nil ---@type stl.c.IFiletreeNodeData|nil
  with_composer(
    "preview-data",
    function(composer)
      composer.__retrieve_file__ = function()
        return "leaf", expected
      end
      assert(basic_props ~= nil, "basic composer props should be captured")
      basic_props.on_preview_rendered(composer._composer, 84)
    end,
    nil,
    nil,
    function(_, _, data)
      actual = data
    end
  )

  t.assert_true(actual == expected, "preview data identity")
end)

t:test("preview treats an empty result as a normal state", function()
  with_composer("empty-preview", function(composer)
    local bufnr = vim.api.nvim_create_buf(false, true)
    local ok, err = pcall(function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "stale preview" })
      composer._last_preview_filepath = "stale.lua"
      composer.__retrieve_nodeuuid__ = function()
        return nil, 0
      end

      local result = composer:render_preview(bufnr, false)
      t.assert_eq("", vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1], "empty preview content")
      t.assert_eq("", result.title, "empty preview title")
      t.assert_false(result.cursorline, "empty preview cursorline")
      t.assert_false(result.number, "empty preview number")
      t.assert_false(result.wrap, "empty preview wrap")
      t.assert_false(result.whitespaces, "empty preview whitespace markers")
      t.assert_nil(composer._last_preview_filepath, "empty preview invalidates cached filepath")

      composer.__retrieve_nodeuuid__ = function()
        return nil, -1
      end
      result = composer:render_preview(bufnr, false)
      t.assert_eq("Unknown lnum(-1)", result.title, "invalid nonzero line remains diagnostic")
    end)

    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
    if not ok then
      error(err, 0)
    end
  end)
end)

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
---@return string
---@return stl.c.IFiletreeNodeData
local function create_file(filepath, filetype)
  local data, uuid = stl.c.Filetree.resolve(filepath, filetype, true)
  return uuid, data
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
    local data = composer._filetree:get(composer._uuids_order[1]) ---@type stl.c.IFiletreeNodeData|nil
    t.assert_true(data ~= nil, "matched data")
    t.assert_eq(canonical_rootpath .. "/src/lib/util.lua", data and data.filepath, "matched canonical filepath")
  end, function(_, rootpath)
    attached_rootpath = rootpath
  end)
end)

t:test("mutation actions cross only the OS boundary", function()
  with_composer("canonical-mutations", function(composer)
    local rootpath = "C:/workspace/project"
    local current_uuid, current_data = create_file(rootpath, "directory")
    local rootdata = current_data
    composer.__retrieve_file__ = function()
      return current_uuid, current_data
    end
    composer.__retrieve_rootdata__ = function()
      return rootdata
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
    current_uuid, current_data = create_file(source_filepath, "file")
    submit("filetree: remove node", "yes")
    t.assert_eq("OS<" .. source_filepath .. ">", delete_filepath, "delete boundary")
    t.assert_eq(current_uuid, removed_uuid, "removed canonical UUID")

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
      local data = composer._filetree:get(stl.c.Filetree.uuid(filepath))
      t.assert_true(data ~= nil, "canonical scanned data: " .. filepath)
      t.assert_eq(filepath, data and data.filepath, "scanned filepath")
    end
  end)
end)

t:test("lexical consumers emit slash-only relative paths", function()
  local confirmed = nil ---@type string[]|nil
  with_composer(
    "canonical-consumers",
    function(composer)
      local rootpath = stl.env.IS_WIN and "C:/workspace/project" or "/workspace/project"
      local main_filepath = rootpath .. "/src/main.lua"
      local util_filepath = rootpath .. "/src/lib/util.lua"
      t:patch_table(composer._scheduler_match, "schedule", function() end)
      t:patch_table(yoz.canonical_path, "get_cwd", function()
        return rootpath
      end)
      composer:reset_filepaths(rootpath, {
        main_filepath,
        util_filepath,
      }, false)

      local bufnr = vim.api.nvim_create_buf(false, true)
      local ok, err = pcall(function()
        composer.result.draw(bufnr)

        local copied = nil ---@type string|nil
        t:patch_table(stl.nvim.fn, "copy", function(filepath)
          copied = filepath
        end)
        t:patch_table(stl.reporter, "info", function() end)
        composer.__retrieve_file__ = function()
          local uuid = stl.c.Filetree.uuid(main_filepath)
          return uuid, composer._filetree:get(uuid)
        end
        retrieve_action(composer, "filetree: copy filepath (relative)")()
        t.assert_eq("src/main.lua", copied, "copied relative filepath")

        local quickfix_items = nil ---@type dot.state.qflist.IItem[]|nil
        t:patch_table(composer._composer, "close", function() end)
        t:patch_table(dot.state.qflist, "push", function(items)
          quickfix_items = items
        end)
        t:patch_table(dot.state.qflist, "open_qflist", function() end)
        retrieve_action(composer, "filetree: send to qflist")()
        t.assert_eq(2, quickfix_items and #quickfix_items, "quickfix item count")
        local quickfix_filenames = {} ---@type table<string, true>
        for _, item in ipairs(quickfix_items or {}) do
          t.assert_false(item.filename:find("\\", 1, true) ~= nil, "slash-only quickfix filename")
          quickfix_filenames[item.filename] = true
        end
        t.assert_true(quickfix_filenames["src/main.lua"], "main quickfix filename")
        t.assert_true(quickfix_filenames["src/lib/util.lua"], "util quickfix filename")

        local directory_uuid = stl.c.Filetree.uuid(rootpath .. "/src")
        composer.__retrieve_nodeuuid__ = function()
          return directory_uuid, 1
        end
        local preview = composer:render_preview(bufnr, true)
        t.assert_eq("src", preview.title, "relative preview title")

        composer:__resolve_confirmation__(stl.c.Filetree.uuid(main_filepath))
        t.assert_eq(1, confirmed and #confirmed, "confirmation count")
        t.assert_eq("src/main.lua", confirmed and confirmed[1], "relative confirmation filepath")
      end)

      if vim.api.nvim_buf_is_valid(bufnr) then
        vim.api.nvim_buf_delete(bufnr, { force = true })
      end
      if not ok then
        error(err, 0)
      end
    end,
    nil,
    function(_, filepaths)
      confirmed = filepaths
    end
  )
end)

t:test("retrieve: resolves location state to leaf data", function()
  local data = { filepath = "/workspace/main.lua" }
  local state = { nodetype = "location", leafuuid = "leaf" }
  local composer = setmetatable({
    _treeview = {
      retrieve = function(_, uuid)
        return uuid == "location" and state or nil
      end,
    },
    _filetree = {
      get = function(_, uuid)
        return uuid == "leaf" and data or nil
      end,
    },
  }, era.m.picker.FiletreeComposer)

  local treeuuid, actual_data, actual_state = composer:__retrieve__("location")

  t.assert_eq("leaf", treeuuid, "resolved tree uuid")
  t.assert_true(actual_data == data, "resolved data identity")
  t.assert_true(actual_state == state, "resolved state identity")
end)

t:run()
