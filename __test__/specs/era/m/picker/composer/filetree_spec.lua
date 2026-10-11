--- Run with: nvim -l __test__/run.lua __test__/specs/era/m/picker/composer/filetree_spec.lua
---@diagnostic disable: invisible

local harness = require("__test__.support.harness")
require("ark.bootstrap").setup()

local t = harness.new("era.m.picker.composer.filetree")
local native = require("__test__.support.result_tree")

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
  local basic_props = nil ---@type era.m.picker.composer.IBasicProps|nil
  local original_new = era.m.picker.BasicComposer.new
  t:patch_table(era.m.picker.BasicComposer, "new", function(props)
    basic_props = props
    return original_new(props)
  end)

  local expected = {
    filepath = "/workspace/main.lua",
    filetype = "file",
  }
  local actual = nil ---@type era.view.result_paths.IFile|nil
  with_composer(
    "preview-data",
    function(composer)
      composer.__retrieve_file__ = function()
        return "leaf", expected
      end
      assert(basic_props ~= nil, "basic composer props should be captured")
      ---@diagnostic disable-next-line: undefined-field
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
      ---@diagnostic disable-next-line: duplicate-set-field
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

      ---@diagnostic disable-next-line: duplicate-set-field
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
      ---@diagnostic disable-next-line: return-type-mismatch
      return keymap.callback
    end
  end
  error("Cannot retrieve action: " .. desc)
end

---@param filepath                      string
---@param filetype                      "directory"|"file"
---@return string
---@return era.view.result_paths.IFile
local function create_file(filepath, filetype)
  local paths = require("era.view.result_paths").new()
  local key = paths:_insert_path(filepath, filetype)
  return key, paths:get(key)
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
    local data = composer._filetree:get(composer._uuids_order[1]) ---@type era.view.result_paths.IFile|nil
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
    local removed_tree_uuid = nil ---@type string|nil
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
    t:patch_table(composer._filetree, "remove", function(_, uuid)
      removed_tree_uuid = uuid
    end)
    t:patch_table(composer, "__refresh_file_indexes__", function() end)
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
    t.assert_eq(current_uuid, removed_tree_uuid, "removed topology UUID")

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

t:test("directory removal synchronizes topology state and indexes", function()
  with_composer("directory-remove-refresh", function(composer)
    local root = "/workspace"
    local directory = root .. "/remove"
    local filepath = directory .. "/file.lua"
    local directory_uuid = require("era.view.result_paths").key(directory)
    local fileuuid = require("era.view.result_paths").key(filepath)
    t:patch_table(composer.result, "get_winnr", function()
      return vim.api.nvim_get_current_win()
    end)
    t:patch_table(composer._scheduler_match, "schedule", function() end)
    t:patch_table(vim.fn, "delete", function()
      return 0
    end)
    t:patch_table(vim.ui, "input", function(_, callback)
      callback("yes")
    end)
    composer:reset_filepaths(root, { filepath }, false)
    composer:__match__("file")
    ---@diagnostic disable-next-line: assign-type-mismatch
    local directory_data = composer._filetree:get(directory_uuid) ---@type era.view.result_paths.IFile
    composer.__retrieve_file__ = function()
      return directory_uuid, directory_data
    end

    retrieve_action(composer, "filetree: remove node")()

    t.assert_false(composer._filetree:contains(directory_uuid), "removed directory topology")
    t.assert_false(composer._filetree:contains(fileuuid), "removed child topology")
    t.assert_nil(composer._treeview:retrieve(directory_uuid), "removed directory state")
    t.assert_nil(composer._treeview:retrieve(fileuuid), "removed child state")
    t.assert_eq(0, #composer._uuids_file, "removed file index")
    t.assert_eq(0, #composer._uuids_order, "removed order index")
    composer:__match__("file")
    t.assert_eq(0, #composer._uuids_order, "removed match index")
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
    native.publish(composer._treeview)
    composer._treeview:set_selected(require("era.view.result_paths").key(source .. "/old.lua"), true)
    native.publish(composer._treeview)

    local scanned = nil ---@type string|nil
    t:patch_table(yoz.canonical_path, "to_os_path", function(filepath)
      return "OS<" .. filepath .. ">"
    end)
    t:patch_table(yoz.fs, "collect_files", function(filepath)
      scanned = filepath
      return {
        files = {
          [[nested\child.lua]],
          "old.lua",
          "root.lua",
        },
      },
        nil
    end)

    composer:__update_tree_after_rename__(source, target .. "/", true)

    native.publish(composer._treeview)

    t.assert_eq("OS<" .. target .. ">", scanned, "directory scan boundary")
    for _, filepath in ipairs({
      target .. "/nested/child.lua",
      target .. "/old.lua",
      target .. "/root.lua",
    }) do
      local data = composer._filetree:get(require("era.view.result_paths").key(filepath))
      t.assert_true(data ~= nil, "canonical scanned data: " .. filepath)
      t.assert_eq(filepath, data and data.filepath, "scanned filepath")
    end

    local fileuuid = require("era.view.result_paths").key(target .. "/old.lua")
    local ancestor_uuid = require("era.view.result_paths").key(yoz.canonical_path.dirname(target, false))
    t.assert_true(composer._treeview:retrieve(ancestor_uuid) ~= nil, "destination ancestor state")
    t.assert_true(composer._treeview:isselected(fileuuid), "moved file selection")

    local bufnr = vim.api.nvim_create_buf(false, true)
    local ok, err = pcall(function()
      native.publish(composer._treeview, { only_selected = true })
      t.assert_true(composer._treeview:retrieve_lnum(fileuuid) ~= nil, "selected moved file projection")
    end)
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
    if not ok then
      error(err, 0)
    end
  end)
end)

t:test("file refresh preserves selection at the new identity", function()
  with_composer("selected-file-refresh", function(composer)
    local source = "/workspace/foo.lua"
    local target = "/workspace/foobar.lua"
    t:patch_table(composer._scheduler_match, "schedule", function() end)
    composer:reset_filepaths("/workspace", { source }, false)
    native.publish(composer._treeview)
    composer._treeview:set_selected(require("era.view.result_paths").key(source), true)
    native.publish(composer._treeview)
    composer._uuid_current = require("era.view.result_paths").key(source)
    composer:__match__("foo")

    composer:__update_tree_after_rename__(source, target, false)

    native.publish(composer._treeview)
    composer:__match__("foo")

    local source_uuid = require("era.view.result_paths").key(source)
    local target_uuid = require("era.view.result_paths").key(target)
    t.assert_true(composer._treeview:isselected(target_uuid), "renamed file selection")
    t.assert_eq(target_uuid, composer._uuid_current, "renamed current identity")
    t.assert_eq(target_uuid, composer._uuids_file[1], "renamed file index")
    t.assert_eq(target_uuid, composer._uuids_order[1], "renamed order index")
    t.assert_false(vim.list_contains(composer._uuids_file, source_uuid), "old file index removed")
  end)
end)

t:test("root directory refresh remaps composer indexes", function()
  local attached = nil ---@type string|nil
  with_composer("root-directory-refresh", function(composer)
    local source = "/workspace/root"
    local target = "/archive/root"
    t:patch_table(composer._scheduler_match, "schedule", function() end)
    t:patch_table(yoz.fs, "collect_files", function()
      return { files = { "file.lua" } }, nil
    end)
    composer:reset_filepaths(source, { source .. "/file.lua" }, false)
    composer._uuid_current = require("era.view.result_paths").key(source .. "/file.lua")

    composer:__update_tree_after_rename__(source, target .. "/", true)

    native.publish(composer._treeview)

    local target_root_uuid = require("era.view.result_paths").key(target)
    local target_file_uuid = require("era.view.result_paths").key(target .. "/file.lua")
    t.assert_eq(target_root_uuid, composer._uuid_root, "renamed attached root")
    t.assert_eq(target_file_uuid, composer._uuid_current, "renamed current child")
    t.assert_eq(target_file_uuid, composer._uuids_file[1], "renamed root file index")
    t.assert_eq(target, attached, "renamed attached callback")
  end, function(_, rootpath)
    attached = rootpath
  end)
end)

t:test("directory refresh preserves an empty destination", function()
  with_composer("empty-directory-refresh", function(composer)
    local source = "/workspace/empty"
    local target = "/archive/empty"
    t:patch_table(composer._scheduler_match, "schedule", function() end)
    t:patch_table(yoz.fs, "collect_files", function()
      return { files = {} }, nil
    end)
    composer._treeview:insert_dirpath(source)

    composer:__update_tree_after_rename__(source, target .. "/", true)

    native.publish(composer._treeview)

    local target_uuid = require("era.view.result_paths").key(target)
    local data = composer._filetree:get(target_uuid) ---@type era.view.result_paths.IFile|nil
    local state = composer._treeview:retrieve(target_uuid) ---@type era.view.result_tree.IEntry|nil
    t.assert_eq(target, data and data.filepath, "empty destination data")
    t.assert_eq("container", state and state.nodetype, "empty destination state")
  end)
end)

t:test("directory overwrite removes the replaced target subtree", function()
  with_composer("directory-overwrite-refresh", function(composer)
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
    native.publish(composer._treeview)
    composer._treeview:set_selected(require("era.view.result_paths").key(source_file), true)
    native.publish(composer._treeview)
    t.assert_true(
      composer._treeview:isselected(require("era.view.result_paths").key(source_file)),
      "publication includes queued selection"
    )
    composer._treeview:set_selected(require("era.view.result_paths").key(stale_file), true)
    native.publish(composer._treeview)

    composer:__update_tree_after_rename__(source, target .. "/", true)

    native.publish(composer._treeview)

    local target_uuid = require("era.view.result_paths").key(target_file)
    local stale_uuid = require("era.view.result_paths").key(stale_file)
    t.assert_true(composer._filetree:contains(target_uuid), "overwritten target file")
    t.assert_true(composer._treeview:isselected(target_uuid), "source selection remapped")
    t.assert_false(composer._filetree:contains(stale_uuid), "stale target topology removed")
    t.assert_nil(composer._treeview:retrieve(stale_uuid), "stale target state removed")
    t.assert_false(composer._treeview:isselected(stale_uuid), "stale target selection removed")
  end)
end)

t:test("directory scan failure rebuilds from known source leafs", function()
  with_composer("directory-scan-failure", function(composer)
    local source = "/workspace/source"
    local target = "/archive/target"
    local source_file = source .. "/known.lua"
    local target_file = target .. "/known.lua"
    local report = nil ---@type table|nil
    local schedule_count = 0
    t:patch_table(composer._scheduler_match, "schedule", function()
      schedule_count = schedule_count + 1
    end)
    t:patch_table(stl.reporter, "error", function(value)
      report = value
    end)
    t:patch_table(yoz.fs, "collect_files", function()
      return nil, { error = "permission denied" }
    end)
    composer:reset_filepaths("/workspace", { source_file }, false)
    native.publish(composer._treeview)
    composer._treeview:set_selected(require("era.view.result_paths").key(source_file), true)
    native.publish(composer._treeview)
    schedule_count = 0

    composer:__update_tree_after_rename__(source, target .. "/", true)

    native.publish(composer._treeview)

    local source_uuid = require("era.view.result_paths").key(source)
    local target_uuid = require("era.view.result_paths").key(target)
    local target_file_uuid = require("era.view.result_paths").key(target_file)
    t.assert_false(composer._filetree:contains(source_uuid), "failed scan removes stale source")
    t.assert_true(composer._filetree:contains(target_uuid), "failed scan keeps target root")
    t.assert_true(composer._filetree:contains(target_file_uuid), "failed scan restores known file")
    t.assert_true(composer._treeview:isselected(target_file_uuid), "failed scan remaps selection")
    t.assert_eq("collect_files_failed", report and report.subject, "failed scan report")
    t.assert_eq(1, schedule_count, "failed scan schedules match refresh")
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
        native.await(composer.result.draw(bufnr))

        local copied = nil ---@type string|nil
        t:patch_table(stl.nvim.fn, "copy", function(filepath)
          copied = filepath
        end)
        t:patch_table(stl.reporter, "info", function() end)
        composer.__retrieve_file__ = function()
          local uuid = require("era.view.result_paths").key(main_filepath)
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

        local directory_uuid = require("era.view.result_paths").key(rootpath .. "/src")
        composer.__retrieve_nodeuuid__ = function()
          return directory_uuid, 1
        end
        local preview = composer:render_preview(bufnr, true)
        t.assert_eq("src", preview.title, "relative preview title")

        composer:__resolve_confirmation__(require("era.view.result_paths").key(main_filepath))
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
      data = function(_, uuid)
        return uuid == "leaf" and data or nil
      end,
    },
  }, era.m.picker.FiletreeComposer)

  local treeuuid, actual_data, actual_state = composer:__retrieve__("location")

  t.assert_eq("leaf", treeuuid, "resolved tree uuid")
  t.assert_true(actual_data == data, "resolved data identity")
  t.assert_true(actual_state == state, "resolved state identity")
end)

t:test("identical path refreshes reuse the producer and observe later path mutations", function()
  with_composer("stable-paths", function(composer)
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
end)

t:test("Enter opens a plain file and waits for an immediately preceding Tab", function()
  with_composer("native-open", function(composer)
    t:patch_table(composer._scheduler_match, "schedule", function() end)
    composer:reset_filepaths("/workspace", { "one.lua", "two.lua" }, false)
    composer.result:create_win({ border = "none", number = false, winhighlight = "" }, {
      row = 0,
      col = 0,
      width = 60,
      height = 8,
    })
    native.await(composer._treeview:ready())
    local paths
    t:patch_table(composer._composer, "close", function() end)
    t:patch_table(composer, "__focus_source_win__", function()
      return nil
    end)
    t:patch_table(dot.win, "open_filepaths", function(_, value)
      paths = value
    end)
    t:patch_table(dot.win, "open_filepath", function(_, value)
      paths = { value }
    end)
    local open = retrieve_action(composer, "filetree: open")
    composer.result.lnum_current:next(1, { silent = true })
    open()
    t.assert_eq("/workspace/one.lua", paths and paths[1], "plain leaf opens directly")
    paths = nil
    composer._treeview:toggle_selection()
    composer.result.lnum_current:next(2, { silent = true })
    open()
    t.wait_until(function()
      return paths ~= nil
    end, 5000)
    t.assert_eq(1, #paths)
    t.assert_eq("/workspace/one.lua", paths[1], "Tab selection wins over the next cursor row")
  end)
end)

t:test("rename restores the native cursor to the new file identity", function()
  with_composer("rename-cursor", function(composer)
    composer:reset_filepaths("/workspace", { "aaa.lua", "bbb.lua", "zzz.lua" }, false)
    composer.result:create_win({ border = "none", number = false, winhighlight = "" }, {
      row = 0,
      col = 0,
      width = 60,
      height = 8,
    })
    local tree = composer._treeview
    native.await(tree:ready())
    composer.result:set_lnum_current(2)
    native.await(tree:ready())
    composer:__update_tree_after_rename__("/workspace/bbb.lua", "/workspace/renamed.lua", false)
    native.await(composer.result.draw())
    native.await(tree:ready())
    local cursor = vim.api.nvim_win_get_cursor(composer.result:get_winnr())[1]
    t.assert_eq("/workspace/renamed.lua", tree:data(tree:retrieve_uuid(cursor)).filepath)
    t.assert_eq(cursor, composer.result.lnum_current:snapshot())
  end)
end)

t:run()
