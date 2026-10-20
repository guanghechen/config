local harness = require("__test__.support.harness")
require("ark.bootstrap").setup()

local t = harness.new()
local treeview = require("__test__.support.treeview")

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
  for _, keymaps in ipairs({ composer.result.keymaps, composer.finder.keymaps }) do
    for _, keymap in ipairs(keymaps) do
      if keymap.desc == desc then
        ---@diagnostic disable-next-line: return-type-mismatch
        return keymap.callback
      end
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

t:test("canonicalizes reset ingress and matches canonical root-relative paths", function()
  local attached_rootpath = nil ---@type string|nil
  with_composer("canonical-filetree", function(composer)
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
  end, function(_, rootpath)
    attached_rootpath = rootpath
  end)
end)

t:test("mutation actions pass captured resources and canonical paths to native Jobs", function()
  with_composer("canonical-mutations", function(composer)
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
    ---@param target                    ?string
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
    ---@param desc                      string
    ---@param input                     string
    ---@return nil
    local function submit(desc, input)
      local restore = t:patch_table(vim.ui, "input", function(_, callback)
        callback(input)
      end)
      retrieve_action(composer, desc)()
      t.wait_until(function()
        return not composer._file_operation_busy
      end, 1000)
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
end)

---@param ui                            __test__.support.UI
---@param expression                    string
---@return nil
local function wait_ui(ui, expression)
  ui:wait_until(function()
    return ui:lua("return " .. expression)
  end, 5000, expression)
end

---@return __test__.support.UI
---@return string
local function new_picker_ui()
  local directory = require("ux.filetree.path").from_os(t:tempdir())
  vim.fn.mkdir(directory .. "/root", "p")
  vim.fn.writefile({ "a" }, directory .. "/root/a.lua")
  vim.fn.writefile({ "b" }, directory .. "/root/b.lua")
  local ui = require("__test__.support.ui").new({ cwd = directory .. "/root" })
  t:defer(function()
    ui:close()
  end)
  ui:start({ width = 100, height = 32, runtime = "ark" })
  ui:lua(
    [[
    local path = ...
    errors = {}
    stl.reporter.error = function(value) errors[#errors + 1] = value.message end
    local o = stl.c.Observable.from_value
    picker = era.m.picker.FiletreeComposer.new({
      name = "file operation", permanent = false, preview = false, title = "file operation",
      search_pattern = o(""), flag_foldempty = o(false), flag_fuzzy = o(false), flag_regex = o(false),
      flag_case_sensitive = o(true), flag_selected = o(false), flag_viewtype = o("tree"),
    })
    test_directory = path
    picker:reset_filepaths(path, { path .. "/a.lua", path .. "/b.lua" }, false)
    picker:focus()
  ]],
    directory .. "/root"
  )
  wait_ui(ui, "picker._treeview.view and picker._treeview.view:frame() and picker.result.lnum_total:snapshot() == 2")
  return ui, directory
end

t:test("create rejects a directory replaced while its prompt is open", function()
  local ui, directory = new_picker_ui()
  ui:lua([[
    vim.ui.input = function(_, callback) pending = callback end
    picker:__file_operation__("create")
  ]])
  wait_ui(ui, "pending ~= nil")
  assert(vim.uv.fs_rename(directory .. "/root", directory .. "/original"))
  assert(vim.uv.fs_mkdir(directory .. "/root", 493))
  ui:lua([[pending("created.txt")]])
  wait_ui(ui, "not picker._file_operation_busy")
  t.assert_nil(vim.uv.fs_stat(directory .. "/root/created.txt"), "replacement directory must remain untouched")
  t.assert_nil(vim.uv.fs_stat(directory .. "/original/created.txt"), "moved directory must remain untouched")
  t.assert_true(ui:lua("return #errors > 0"), "stale target must be reported")
end)

for _, phase in ipairs({ "before action", "during prompt" }) do
  t:test("an old Frame rename preserves a producer replaced " .. phase, function()
    local ui = new_picker_ui()
    ui:lua([[
      vim.cmd.stopinsert()
      vim.api.nvim_set_current_win(picker.result:get_winnr())
      picker.result:set_lnum_current(1)
      vim.cmd.normal({args={"V"}, bang=true})
      vim.ui.input = function(_, callback) pending = callback end
    ]])
    if phase == "during prompt" then
      ui:lua([[picker:__file_operation__("rename")]])
      wait_ui(ui, "pending ~= nil")
    end
    ui:lua([[picker:reset_filepaths(test_directory, {test_directory .. "/b.lua"}, false)]])
    wait_ui(
      ui,
      [[
      picker._treeview.state:snapshot():source():id(require("era.view.result_paths").key(test_directory .. "/a.lua")) == nil
    ]]
    )
    t.assert_eq(
      "a.lua",
      ui:lua([[
      local _, item = picker:__retrieve_file__()
      return item and item.basename
    ]]),
      "the visible Frame still owns the original action target"
    )
    if phase == "before action" then
      ui:lua([[picker:__file_operation__("rename")]])
      wait_ui(ui, "pending ~= nil")
    end
    ui:lua([[pending("renamed.lua")]])
    wait_ui(
      ui,
      [[vim.uv.fs_stat(test_directory .. "/renamed.lua") ~= nil and not require("era.m.filetree.jobs").pending()]]
    )
    ui:lua([[vim.cmd.normal({args={vim.keycode("<Esc>")}, bang=true})]])
    wait_ui(ui, "not picker._file_operation_busy")
    local files = ui:lua([[
      local files = {}
      for _, uuid in ipairs(picker._uuids_order:keys()) do
        files[#files + 1] = picker._filetree:get(uuid).basename
      end
      return files
    ]])
    t.assert_eq(1, #files, "the replacement producer must keep its own membership")
    t.assert_eq("b.lua", files[1])
    t.assert_eq(0, ui:lua("return #errors"))
  end)
end

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

    retrieve_action(composer, "filetree: remove node")()
    t.wait_until(function()
      return not composer._file_operation_busy
    end, 1000)

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
end)

t:test("directory moves preserve only producer membership without rescanning disk", function()
  with_composer("canonical-directory-refresh", function(composer)
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
end)

t:test("file refresh preserves selection at the new identity", function()
  with_composer("selected-file-refresh", function(composer)
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

    composer:__update_tree_after_rename__(source, target .. "/")

    treeview.publish(composer._treeview)

    local target_root_uuid = require("era.view.result_paths").key(target)
    local target_file_uuid = require("era.view.result_paths").key(target .. "/file.lua")
    t.assert_eq(target_root_uuid, composer._uuid_root, "renamed attached root")
    t.assert_eq(target_file_uuid, composer._uuid_current, "renamed current child")
    t.assert_same({ target_file_uuid }, composer._uuids_order:keys(), "renamed root file index")
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

    composer:__update_tree_after_rename__(source, target .. "/")

    treeview.publish(composer._treeview)

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
end)

t:test("directory moves retain location metadata and native selection without disk scans", function()
  with_composer("location-move", function(composer)
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
        treeview.await(composer.result.draw(bufnr))

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
        composer.result:create_win({ border = "none", number = false, winhighlight = "" }, {
          row = 0,
          col = 0,
          width = 60,
          height = 8,
        })
        treeview.await(composer._treeview:ready())
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

t:test("expansion actions typed ahead act on the tree their earlier actions produce", function()
  with_composer("typeahead-expansion", function(composer)
    t:patch_table(composer._scheduler_match, "schedule", function() end)
    composer:reset_filepaths("/workspace", { "src/one.lua", "src/two.lua" }, false)
    composer.result:create_win({ border = "none", number = false, winhighlight = "" }, {
      row = 0,
      col = 0,
      width = 60,
      height = 8,
    })
    local tree = composer._treeview
    treeview.await(tree:ready())
    local errors = {} ---@type table[]
    t:patch_table(stl.reporter, "error", function(value)
      errors[#errors + 1] = value
    end)
    local src = require("era.view.result_paths").key("/workspace/src")
    local open, collapse = retrieve_action(composer, "filetree: open"), retrieve_action(composer, "filetree: collapse")
    composer.result.lnum_current:next(tree:retrieve_lnum(src), { silent = true })
    treeview.assert_typed_ahead(t, tree, src, open, collapse)
    t.assert_eq(0, #errors, vim.inspect(errors))
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
end)

t:test("quickfix reads the displayed files after an unpublished producer reset", function()
  with_composer("published-quickfix", function(composer)
    local root = "/workspace"
    t:patch_table(composer._scheduler_match, "schedule", function() end)
    t:patch_table(composer._composer, "close", function() end)
    local exported
    t:patch_table(dot.state.qflist, "push", function(items)
      exported = items
    end)
    t:patch_table(dot.state.qflist, "open_qflist", function() end)
    composer:reset_filepaths(root, { "a.lua", "b.lua" }, false)
    composer.result:create_win({ border = "none", number = false, winhighlight = "" }, {
      row = 0,
      col = 0,
      width = 60,
      height = 8,
    })
    treeview.await(composer._treeview:ready())
    local frame = composer._treeview:frame()
    composer:reset_filepaths(root, { "replacement.lua" }, false)
    t.assert_eq(frame:id(), composer._treeview:frame():id())
    retrieve_action(composer, "filetree: send to qflist")()
    t.assert_eq(2, exported and #exported or 0)
    t.assert_eq(
      yoz.canonical_path.relative(yoz.canonical_path.get_cwd(), root .. "/a.lua", false),
      exported[1].filename
    )
    t.assert_eq(
      yoz.canonical_path.relative(yoz.canonical_path.get_cwd(), root .. "/b.lua", false),
      exported[2].filename
    )
  end)
end)

t:test("a desynced result rejects hide actions before changing producer visibility", function()
  with_composer("guarded-hide", function(composer)
    t:patch_table(composer._scheduler_match, "schedule", function() end)
    composer:reset_filepaths("/workspace", { "a.lua" }, false)
    composer.result:create_win({ border = "none", number = false, winhighlight = "" }, {
      row = 0,
      col = 0,
      width = 60,
      height = 8,
    })
    local tree = composer._treeview
    treeview.await(tree:ready())
    local key = tree:retrieve_uuid(1)
    composer.result:set_lnum_current(1)
    treeview.await(tree:ready())
    t.assert_eq(1, composer.result.lnum_current:snapshot())
    tree.view._desynced = true
    retrieve_action(composer, "filetree: mark the node invisible")()
    t.assert_true(tree:isvisible(key))
    t.assert_nil(next(tree._hidden))
    tree.view._desynced = false
    retrieve_action(composer, "filetree: mark the node invisible")()
    t.assert_false(tree:isvisible(key), "the same action runs against a valid surface")
  end)
end)

t:test("confirmation and create keep the displayed root after an unpublished cross-root reset", function()
  with_composer("published-root", function(composer)
    local root = "/workspace/picker-actions"
    local Paths = require("era.view.result_paths")
    t:patch_table(composer._scheduler_match, "schedule", function() end)
    t:patch_table(composer._composer, "close", function() end)
    composer:reset_filepaths(root, { "dir/a.lua" }, false)
    composer.result:create_win({ border = "none", number = false, winhighlight = "" }, {
      row = 0,
      col = 0,
      width = 60,
      height = 8,
    })
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
    end, 1000)
    t.assert_eq(root, captured)
    t.assert_eq("dir/a.lua", default)
  end)
end)

t:test("attach and file-location toggle interpret the displayed nodes after producer replacement", function()
  local attached = {}
  with_composer("published-attach", function(composer)
    local Paths = require("era.view.result_paths")
    local root = "/workspace/picker-actions"
    t:patch_table(composer._scheduler_match, "schedule", function() end)
    composer:reset_filepaths(root, { "dir/a.lua:3:1" }, true)
    composer.result:create_win({ border = "none", number = false, winhighlight = "" }, {
      row = 0,
      col = 0,
      width = 60,
      height = 8,
    })
    local tree = composer._treeview
    treeview.await(tree:ready())
    local directory, key = Paths.key(root .. "/dir"), Paths.key(root .. "/dir/a.lua")
    composer.result:set_lnum_current(tree:retrieve_lnum(directory))
    treeview.await(tree:ready())
    local frame = tree:frame()
    composer:reset_filepaths("/workspace/new-root", { "replacement.lua" }, false)
    attached = {}
    retrieve_action(composer, "filetree: change root")()
    t.assert_eq(directory, composer._uuid_root)
    t.assert_same({ root .. "/dir" }, attached)
    local toggled
    t:patch_table(tree, "collapse", function(_, uuid, kind, recursive, captured)
      toggled = { uuid, kind, recursive }
      t.assert_true(captured == frame)
    end)
    composer:__toggle_node__(key, false, false)
    t.assert_same({ key, "toggle", false }, toggled)
  end, function(_, path)
    attached[#attached + 1] = path
  end)
end)

t:run()
