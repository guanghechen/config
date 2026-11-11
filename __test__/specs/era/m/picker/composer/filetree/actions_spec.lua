local harness = require("__test__.support.harness")
require("ark.bootstrap").setup()

local t = harness.new()
local bootstrap = require("__test__.support.bootstrap")
local picker = require("__test__.support.picker")
local treeview = require("__test__.support.treeview")

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
  local composer = picker.filetree_composer(t, "preview-data", nil, nil, function(_, _, data)
    actual = data
  end)
  composer.__retrieve_file__ = function()
    return "leaf", expected
  end
  assert(basic_props ~= nil, "basic composer props should be captured")
  ---@diagnostic disable-next-line: undefined-field
  basic_props.on_preview_rendered(composer._composer, 84)

  t.assert_true(actual == expected, "preview data identity")
end)

t:test("preview treats an empty result as a normal state", function()
  local composer = picker.filetree_composer(t, "empty-preview")
  local bufnr = t:buffer({ "stale preview" })
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

---@param filepath                      string
---@param filetype                      "directory"|"file"
---@return string
---@return era.view.result_paths.IFile
local function create_file(filepath, filetype)
  local paths = require("era.view.result_paths").new()
  local key = paths:_insert_path(filepath, filetype)
  return key, paths:get(key)
end

t:test("mutation actions pass captured resources and canonical paths to native Jobs", function()
  local composer = picker.filetree_composer(t, "canonical-mutations")
  local Jobs = require("era.m.filetree.jobs")
  local Future = require("stl.c.future")
  local rootpath = "C:/workspace/project"
  local current_uuid, current_data = create_file(rootpath, "directory")
  local rootdata = current_data
  composer._filetree:insert_directory_absolute(rootpath)
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
  t:patch_table(composer, "__refresh_file_indexes__", function() end)
  local captured_path, created_path, moved_path, removed_uuid, inserted_path
  local captured_source, captured_resource = {}, {}
  captured_resource.info = function()
    return { directory = current_data.filetype == "directory" }
  end
  captured_resource.source = function()
    return captured_source
  end
  captured_resource.node = function()
    return "captured-node"
  end
  t:patch_table(Jobs, "capture", function(path)
    captured_path = path
    return Future.resolve({ data = {}, resource = captured_resource })
  end)
  ---@param target                      ?string
  ---@return stl.c.Future
  local function result(target)
    return Future.resolve({ status = {}, success = true, items = { { status = "success", target = target } } })
  end
  t:patch_table(Jobs, "create", function(_, resource, path)
    t.assert_true(resource == captured_resource, "creation retains the captured target")
    created_path = path
    return result(path)
  end)
  t:patch_table(Jobs, "run", function(_, plan)
    t.assert_eq("delete", plan.kind)
    t.assert_true(plan.source == captured_source)
    t.assert_eq("captured-node", plan.nodes[1])
    return result()
  end)
  t:patch_table(Jobs, "move", function(_, resource, path, overwrite)
    t.assert_true(resource == captured_resource)
    moved_path = path
    local decision = overwrite({ target_label = path })
    t.assert_true(decision:get_result())
    return result(path)
  end)
  t:patch_table(vim.ui, "select", function(_, _, callback)
    callback("Yes")
  end)
  t:patch_table(composer._treeview, "insert_filepath", function(_, path)
    inserted_path = path
  end)
  t:patch_table(composer._treeview, "remove", function(_, uuid)
    removed_uuid = uuid
  end)
  t:patch_table(composer._filetree, "remove", function() end)
  local update
  composer.__update_tree_after_rename__ = function(_, from, to)
    update = { from, to }
  end
  ---@param desc                        string
  ---@param input                       string
  ---@return nil
  local function submit(desc, input)
    local restore = t:patch_table(vim.ui, "input", function(_, callback)
      callback(input)
    end)
    picker.action(composer, desc)()
    t.wait_until(function()
      return not composer._file_operation_busy
    end, 5000)
    restore()
  end
  submit("filetree: create node", [[nested\new.lua]])
  t.assert_eq(rootpath, captured_path)
  t.assert_eq("nested/new.lua", created_path)
  t.assert_eq(rootpath .. "/" .. created_path, inserted_path)
  submit("filetree: create node", "../sibling/new.lua")
  t.assert_eq("../sibling/new.lua", created_path)
  t.assert_eq("C:/workspace/sibling/new.lua", inserted_path)
  submit("filetree: create node", [[D:\archive\new.lua]])
  t.assert_eq("D:/archive/new.lua", created_path, "another volume stays an explicit absolute target")
  t.assert_eq(created_path, inserted_path)
  local source = rootpath .. "/src/main.lua"
  current_uuid, current_data = create_file(source, "file")
  composer._filetree:insert_file_absolute(source)
  submit("filetree: remove node", "yes")
  t.assert_eq(source, captured_path)
  t.assert_eq(current_uuid, removed_uuid)
  submit("filetree: rename node", "renamed.lua")
  t.assert_eq(rootpath .. "/src/renamed.lua", moved_path)
  t.assert_eq(source, update[1])
  t.assert_eq(moved_path, update[2])
  submit("filetree: move node", [[D:\archive\moved.lua]])
  t.assert_eq("D:/archive/moved.lua", moved_path)
  t.assert_eq(moved_path, update[2])
  current_uuid, current_data = create_file(rootpath .. "/nested/old", "directory")
  composer._filetree:insert_directory_absolute(current_data.filepath)
  moved_path = nil
  submit("filetree: rename node", "old/")
  t.assert_nil(moved_path, "accepting a nested directory's default name must not move it to the result root")
  submit("filetree: rename node", "new/")
  t.assert_eq(rootpath .. "/nested/new", moved_path, "a trailing slash is a directory marker, not a parent path")
end)

t:test("lexical consumers emit slash-only relative paths", function()
  local confirmed = nil ---@type string[]|nil
  local composer = picker.filetree_composer(t, "canonical-consumers", nil, function(_, filepaths)
    confirmed = filepaths
  end)
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

  local bufnr = t:buffer()
  treeview.await(composer.result.draw(bufnr))

  local copied = nil ---@type string|nil
  t:patch_table(stl.nvim.fn, "copy", function(filepath)
    copied = filepath
  end)
  bootstrap.with_reporter(t)
  composer.__retrieve_file__ = function()
    local uuid = require("era.view.result_paths").key(main_filepath)
    return uuid, composer._filetree:get(uuid)
  end
  picker.action(composer, "filetree: copy filepath (relative)")()
  t.assert_eq("src/main.lua", copied, "copied relative filepath")

  local quickfix_items = nil ---@type dot.state.qflist.IItem[]|nil
  t:patch_table(composer._composer, "close", function() end)
  t:patch_table(dot.state.qflist, "push", function(items)
    quickfix_items = items
  end)
  t:patch_table(dot.state.qflist, "open_qflist", function() end)
  picker.show_result(composer, 60, 8)
  treeview.await(composer._treeview:ready())
  picker.action(composer, "filetree: send to qflist")()
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

t:test("copy filepath offers the choices one row below and four columns right of the result cursor", function()
  local composer = picker.filetree_composer(t, "copy-placement")
  local rootpath = stl.env.IS_WIN and "C:/workspace/project" or "/workspace/project"
  local main_filepath = rootpath .. "/src/main.lua"
  t:patch_table(composer._scheduler_match, "schedule", function() end)
  composer:reset_filepaths(rootpath, { main_filepath }, false)
  picker.show_result(composer, 60, 8)
  treeview.await(composer._treeview:ready())
  composer.__retrieve_file__ = function()
    local uuid = require("era.view.result_paths").key(main_filepath)
    return uuid, composer._filetree:get(uuid)
  end
  picker.assert_copy_choices_at_cursor(t, composer, "filetree: copy filepath")
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

t:test("Enter opens a plain file and waits for an immediately preceding Tab", function()
  local composer = picker.filetree_composer(t, "native-open")
  t:patch_table(composer._scheduler_match, "schedule", function() end)
  composer:reset_filepaths("/workspace", { "one.lua", "two.lua" }, false)
  picker.show_result(composer, 60, 8)
  treeview.await(composer._treeview:ready())
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
  local open = picker.action(composer, "filetree: open")
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

t:test("expansion actions typed ahead act on the tree their earlier actions produce", function()
  local composer = picker.filetree_composer(t, "typeahead-expansion")
  t:patch_table(composer._scheduler_match, "schedule", function() end)
  composer:reset_filepaths("/workspace", { "src/one.lua", "src/two.lua" }, false)
  picker.show_result(composer, 60, 8)
  local tree = composer._treeview
  treeview.await(tree:ready())
  local reports = bootstrap.with_reporter(t)
  local src = require("era.view.result_paths").key("/workspace/src")
  local open, collapse = picker.action(composer, "filetree: open"), picker.action(composer, "filetree: collapse")
  composer.result.lnum_current:next(tree:retrieve_lnum(src), { silent = true })
  treeview.assert_typed_ahead(t, tree, src, open, collapse)
  t.assert_eq(0, #reports.error, vim.inspect(reports.error))
end)

t:test("quickfix reads the displayed files after an unpublished producer reset", function()
  local composer = picker.filetree_composer(t, "published-quickfix")
  local root = "/workspace"
  t:patch_table(composer._scheduler_match, "schedule", function() end)
  t:patch_table(composer._composer, "close", function() end)
  local exported
  t:patch_table(dot.state.qflist, "push", function(items)
    exported = items
  end)
  t:patch_table(dot.state.qflist, "open_qflist", function() end)
  composer:reset_filepaths(root, { "a.lua", "b.lua" }, false)
  picker.show_result(composer, 60, 8)
  treeview.await(composer._treeview:ready())
  local frame = composer._treeview:frame()
  composer:reset_filepaths(root, { "replacement.lua" }, false)
  t.assert_eq(frame:id(), composer._treeview:frame():id())
  picker.action(composer, "filetree: send to qflist")()
  t.assert_eq(2, exported and #exported or 0)
  t.assert_eq(yoz.canonical_path.relative(yoz.canonical_path.get_cwd(), root .. "/a.lua", false), exported[1].filename)
  t.assert_eq(yoz.canonical_path.relative(yoz.canonical_path.get_cwd(), root .. "/b.lua", false), exported[2].filename)
end)

t:test("a desynced result rejects hide actions before changing producer visibility", function()
  local composer = picker.filetree_composer(t, "guarded-hide")
  t:patch_table(composer._scheduler_match, "schedule", function() end)
  composer:reset_filepaths("/workspace", { "a.lua" }, false)
  picker.show_result(composer, 60, 8)
  local tree = composer._treeview
  treeview.await(tree:ready())
  local key = tree:retrieve_uuid(1)
  composer.result:set_lnum_current(1)
  treeview.await(tree:ready())
  t.assert_eq(1, composer.result.lnum_current:snapshot())
  tree.view._desynced = true
  picker.action(composer, "filetree: mark the node invisible")()
  t.assert_true(tree:isvisible(key))
  t.assert_nil(next(tree._hidden))
  tree.view._desynced = false
  picker.action(composer, "filetree: mark the node invisible")()
  t.assert_false(tree:isvisible(key), "the same action runs against a valid surface")
end)

t:test("confirmation and create keep the displayed root after an unpublished cross-root reset", function()
  local composer = picker.filetree_composer(t, "published-root")
  local root = "/workspace/picker-actions"
  local Paths = require("era.view.result_paths")
  t:patch_table(composer._scheduler_match, "schedule", function() end)
  t:patch_table(composer._composer, "close", function() end)
  composer:reset_filepaths(root, { "dir/a.lua" }, false)
  picker.show_result(composer, 60, 8)
  local tree = composer._treeview
  treeview.await(tree:ready())
  local key = Paths.key(root .. "/dir/a.lua")
  composer.result:set_lnum_current(tree:retrieve_lnum(key))
  treeview.await(tree:ready())
  local frame = tree:frame()
  composer:reset_filepaths("/workspace/new-root", { "replacement.lua" }, false)
  t.assert_eq(frame:id(), tree:frame():id())
  local confirmed, captured, default
  t:patch_table(composer, "_on_confirm", function(_, paths)
    confirmed = paths
  end)
  composer:__resolve_confirmation__(key)
  t.assert_same({ "dir/a.lua" }, confirmed)
  t:patch_table(require("era.m.filetree.jobs"), "capture", function(path)
    captured = path
    return stl.c.Future.resolve({ data = {}, resource = {} })
  end)
  t:patch_table(vim.ui, "input", function(options, callback)
    default = options.default
    callback(nil)
  end)
  composer:__file_operation__("create")
  t.wait_until(function()
    return not composer._file_operation_busy
  end, 5000)
  t.assert_eq(root, captured)
  t.assert_eq("dir/a.lua", default)
end)

t:test("attach and file-location toggle interpret the displayed nodes after producer replacement", function()
  local attached = {}
  local composer = picker.filetree_composer(t, "published-attach", function(_, path)
    attached[#attached + 1] = path
  end)
  local Paths = require("era.view.result_paths")
  local root = "/workspace/picker-actions"
  t:patch_table(composer._scheduler_match, "schedule", function() end)
  composer:reset_filepaths(root, { "dir/a.lua:3:1" }, true)
  picker.show_result(composer, 60, 8)
  local tree = composer._treeview
  treeview.await(tree:ready())
  local directory, key = Paths.key(root .. "/dir"), Paths.key(root .. "/dir/a.lua")
  composer.result:set_lnum_current(tree:retrieve_lnum(directory))
  treeview.await(tree:ready())
  local frame = tree:frame()
  composer:reset_filepaths("/workspace/new-root", { "replacement.lua" }, false)
  attached = {}
  picker.action(composer, "filetree: change root")()
  t.assert_eq(directory, composer._uuid_root)
  t.assert_same({ root .. "/dir" }, attached)
  local toggled
  t:patch_table(tree, "collapse", function(_, uuid, kind, recursive, captured)
    toggled = { uuid, kind, recursive }
    t.assert_true(captured == frame)
  end)
  composer:__toggle_node__(key, false, false)
  t.assert_same({ key, "toggle", false }, toggled)
end)

t:test("Tab toggles the selection from the finder while a filter is being typed", function()
  local composer = picker.filetree_composer(t, "finder-tab")
  local tab ---@type stl.t.IKeymap|nil
  for _, keymap in ipairs(composer.finder.keymaps) do
    if keymap.key == "<Tab>" then
      tab = keymap
    end
  end
  t.assert_eq("filetree: toggle selection", tab and tab.desc, "finder Tab")
  t.assert_true(vim.list_contains(tab and tab.modes or {}, "i"), "Insert mode, like Normal mode and the result pane")
end)

t:test("confirming the selected files in a picker that closes for good reports them", function()
  local composer = picker.filetree_composer(t, "confirm-closes")
  local Paths = require("era.view.result_paths")
  local root = "/workspace/confirm-closes"
  t:patch_table(composer._scheduler_match, "schedule", function() end)
  composer:reset_filepaths(root, { "a.lua", "b.lua" }, false)
  picker.show_result(composer, 60, 8)
  local tree = composer._treeview
  treeview.await(tree:ready())
  tree:set_selected(Paths.key(root .. "/a.lua"), true)
  treeview.await(tree:ready())
  local confirmed = nil ---@type string[]|nil
  t:patch_table(composer, "_on_confirm", function(_, paths)
    confirmed = paths
  end)

  composer:__resolve_confirmation__(Paths.key(root))
  t.assert_same({ root .. "/a.lua" }, confirmed)
end)

t:test("era.m.picker.composer.filetree resolves a published parent identity for collapse", function()
  local tree = picker.branch_tree(t)
  treeview.applied(tree:publish({ mode = "tree", rootuuid = "root" }))
  local composer = setmetatable({ _treeview = tree }, { __index = require("era.m.picker.composer.filetree") })
  local row, key = composer:__retrieve_lnum_parent__("two")
  t.assert_eq(1, row)
  t.assert_eq("dir", key)
  t.assert_nil(composer:__retrieve_lnum_parent__(nil))
  t.assert_nil(composer:__retrieve_lnum_parent__("absent"))
  tree:collapse(key, "collapse", true)
  treeview.applied(tree:ready())
  t.assert_nil(tree:retrieve_lnum("two"))
  t.assert_true(tree:retrieve("dir").collapsed)
end)

t:test("era.m.picker.composer.filetree navigates from a List location to its displayed file", function()
  local tree = picker.branch_tree(t)
  tree:insert("one", {
    nodetype = "leaf",
    locations = { { nodetype = "location", leafuuid = "one", locationuuid = "one:1", lnum = 1 } },
  })
  treeview.applied(tree:publish({ mode = "list", rootuuid = "root", orders = { "one" } }))
  local composer = setmetatable({ _treeview = tree }, { __index = require("era.m.picker.composer.filetree") })
  local row, key = composer:__retrieve_lnum_parent__("one:1")
  t.assert_eq(1, row)
  t.assert_eq("one", key)
end)

t:run()
