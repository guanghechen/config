require("ark.bootstrap").setup()
local t = require("__test__.support.harness").new()
local bootstrap = require("__test__.support.bootstrap")
local picker = require("__test__.support.picker")
local treeview = require("__test__.support.treeview")
local Paths = require("era.view.result_paths")
local root = "/workspace/searcher-actions"

---@param on_attached                   ?era.m.searcher.composer.filetree.IOnAttached
---@param frecency                      ?stl.c.Frecency
---@return era.m.searcher.FiletreeComposer
local function fixture(on_attached, frecency)
  local composer = picker.searcher(t, {
    name = "published-actions",
    permanent = false,
    preview = false,
    title = "published actions",
    includes = { "*.lua" },
    max_matches = 100,
    rootpath = root,
    on_attached = on_attached,
    frecency = frecency,
  })
  t:defer(function()
    vim.cmd.normal({ args = { vim.keycode("<Esc>") }, bang = true })
  end)
  t:patch_table(composer, "schedule_search", function() end)
  composer:reset_filepaths(root, root, { "dir/a.lua", "dir/b.lua", "other.lua" })
  local tree = composer._treeview
  for index, path in ipairs({ "dir/a.lua", "dir/b.lua", "other.lua" }) do
    tree:add_location(Paths.key(root .. "/" .. path), {
      lnum = index + 2,
      col = 1,
      col_end = 4,
      text = "match " .. index,
      match = { preview = { offset = index, lnum = index + 2, col = 1 } },
    })
    -- As a search finds them: empty and modified at the epoch, which `as_searched` reports.
    tree.entries[Paths.key(root .. "/" .. path)].filematch =
      { filepath = root .. "/" .. path, relative = path, matches = {}, size = 0, mtime_sec = 0, mtime_nsec = 0 }
  end
  picker.show_result(composer, 60, 12)
  treeview.await(composer.result.draw())
  treeview.await(tree:ready())
  composer._published_search_inputs = composer:__snapshot_search_inputs__()
  t.assert_true(composer:__is_search_projection_current__())
  t.assert_true(tree.view:_valid())
  return composer
end

-- The files of the fixture, which exist nowhere, as the search found them.
---@return nil
local function as_searched()
  t:patch_table(vim.uv, "fs_stat", function()
    return { size = 0, mtime = { sec = 0, nsec = 0 } }
  end)
end

t:test("files are ordered by frecency, the most visited first", function()
  local frecency = stl.c.Frecency.new({ items = {} })
  local a, b, other = Paths.key(root .. "/dir/a.lua"), Paths.key(root .. "/dir/b.lua"), Paths.key(root .. "/other.lua")
  frecency:access(other)
  frecency:access(other)
  frecency:access(b)
  local composer = fixture(nil, frecency)
  t.assert_same({ other, b, a }, composer._uuids_order, "frecency order")
end)

t:test("copy filepath offers the choices one row below and four columns right of the result cursor", function()
  local composer = fixture()
  t:patch_table(composer, "__retrieve_filedata__", function()
    return { filepath = root .. "/other.lua" }
  end)
  picker.assert_copy_choices_at_cursor(t, composer, "searcher: copy filepath")
end)

t:test("quickfix keeps published file locations after the producer is replaced", function()
  local composer = fixture()
  local tree = composer._treeview
  local frame = tree:frame()
  local exported
  t:patch_table(composer._composer, "close", function() end)
  t:patch_table(dot.state.qflist, "push", function(items)
    exported = items
  end)
  t:patch_table(dot.state.qflist, "open_qflist", function() end)
  composer:reset_filepaths(root, root, { "replacement.lua" })
  t.assert_eq(frame:id(), tree:frame():id())
  picker.action(composer, "searcher: send to qflist")()
  t.assert_eq(3, exported and #exported or 0, "location rows must not duplicate their file export")
  for index, path in ipairs({ "dir/a.lua", "dir/b.lua", "other.lua" }) do
    t.assert_eq(
      yoz.canonical_path.relative(yoz.canonical_path.get_cwd(), root .. "/" .. path, false),
      exported[index].filename
    )
    t.assert_eq(index + 2, exported[index].lnum)
    t.assert_eq("match " .. index, exported[index].text)
  end
end)

t:test("AI location targets retain the captured file and coordinates after an unpublished reset", function()
  local composer = fixture()
  local tree = composer._treeview
  local key = Paths.key(root .. "/dir/a.lua")
  local location = tree:retrieve(key).locations[1]
  composer.result:set_lnum_current(tree:retrieve_lnum(location.locationuuid))
  treeview.await(tree:ready())
  local targets
  t:patch_table(era.fn, "add_locations_to_ai", function(value)
    targets = value
  end)
  composer:reset_filepaths(root, root, { "replacement.lua" })
  picker.action(composer, "searcher: add to ai")()
  t.assert_eq(1, targets and #targets or 0)
  t.assert_eq(root .. "/dir/a.lua", targets[1].filepath)
  t.assert_eq(location.lnum, targets[1].start_lnum)
  t.assert_eq(location.col + 1, targets[1].start_col)
end)

t:test("desynced Searcher ranges cannot hide files or invoke replacement", function()
  local composer = fixture()
  local tree = composer._treeview
  local replacements = 0
  t:patch_table(composer, "__replace_file__", function()
    replacements = replacements + 1
    return false
  end)
  tree.view._desynced = true
  picker.action(composer, "searcher: mark the node invisible")()
  picker.action(composer, "searcher: mark the subroot invisible")()
  picker.action(composer, "searcher: replace all files")()
  picker.action(composer, "search: replace file")()
  t.assert_nil(next(tree._hidden))
  t.assert_eq(0, replacements)
  tree.view._desynced = false
  picker.action(composer, "searcher: replace all files")()
  t.assert_eq(3, replacements)
end)

t:test("replacement uses the active Visual endpoint and only the captured container range", function()
  local composer = fixture()
  local tree = composer._treeview
  local winnr = composer.result:get_winnr()
  vim.api.nvim_set_current_win(winnr)
  local directory = tree:retrieve_lnum(Paths.key(root .. "/dir"))
  local first = tree:retrieve_lnum(Paths.key(root .. "/dir/a.lua"))
  local last = tree:retrieve_lnum(Paths.key(root .. "/dir/b.lua"))
  local replaced = {}
  t:patch_table(composer, "__replace_file__", function(_, data)
    replaced[#replaced + 1] = data.filepath
    return false
  end)
  local replace = picker.action(composer, "search: replace file")
  vim.api.nvim_win_set_cursor(winnr, { directory, 0 })
  vim.cmd.normal({ args = { "V" }, bang = true })
  vim.api.nvim_win_set_cursor(winnr, { first, 0 })
  replace()
  t.assert_same({ root .. "/dir/a.lua" }, replaced, "an active file does not replace the earlier container")
  replaced = {}
  vim.api.nvim_win_set_cursor(winnr, { last, 0 })
  vim.cmd.normal({ args = { "V" }, bang = true })
  vim.api.nvim_win_set_cursor(winnr, { directory, 0 })
  replace()
  t.assert_same({ root .. "/dir/a.lua", root .. "/dir/b.lua" }, replaced)
  t.assert_eq("n", vim.fn.mode())
end)

t:test("bulk replacement updates producer locations and leaves the captured metadata immutable", function()
  local composer = fixture()
  local tree = composer._treeview
  local frame = tree:frame()
  local key = Paths.key(root .. "/dir/a.lua")
  local original = tree:retrieve(key, frame)
  local replacements = {}
  as_searched()
  t:patch_table(yoz.replace, "replace_file_by_matches", function(options)
    replacements[#replacements + 1] = options.filepath
    return true
  end)
  picker.action(composer, "searcher: replace all files")()
  t.assert_eq(3, #replacements)
  t.assert_same({}, tree.entries[key].locations)
  t.assert_eq(1, #original.locations)
  t.assert_eq("match 1", original.locations[1].text)
end)

t:test("confirmation resolves relative paths against the displayed root after a cross-root reset", function()
  local composer = fixture()
  local tree = composer._treeview
  local key = Paths.key(root .. "/dir/a.lua")
  local confirmed
  t:patch_table(composer._composer, "close", function() end)
  t:patch_table(composer, "_on_confirm", function(_, paths)
    confirmed = paths
  end)
  composer:reset_filepaths("/workspace/new-root", "/workspace/new-root", { "replacement.lua" })
  composer:__resolve_confirmation__(key)
  t.assert_same({ "dir/a.lua" }, confirmed)
end)

t:test("attach and toggle retain the displayed file identity and locations after replacement", function()
  local attached = {}
  local composer = fixture(function(_, path)
    attached[#attached + 1] = path
  end)
  local tree = composer._treeview
  local key = Paths.key(root .. "/dir/a.lua")
  composer.result:set_lnum_current(tree:retrieve_lnum(key))
  treeview.await(tree:ready())
  local frame = tree:frame()
  composer:reset_filepaths("/workspace/new-root", "/workspace/new-root", { "replacement.lua" })
  attached = {}
  picker.action(composer, "searcher: change root")()
  t.assert_eq(key, composer._uuid_root)
  t.assert_same({ root .. "/dir/a.lua" }, attached)
  local toggled
  t:patch_table(tree, "collapse", function(_, uuid, kind, recursive, captured)
    toggled = { uuid, kind, recursive }
    t.assert_true(captured == frame)
  end)
  composer:__toggle_node__(key, false, false)
  t.assert_same({ key, "toggle", false }, toggled)
end)

t:test("parent attachment uses the displayed root ancestry after a pending root replacement", function()
  local attached = {}
  local composer = fixture(function(_, path)
    attached[#attached + 1] = path
  end)
  composer._uuid_root = Paths.key(root .. "/dir")
  treeview.await(composer.result.draw())
  treeview.await(composer._treeview:ready())
  composer:reset_filepaths("/workspace/new-root", "/workspace/new-root", { "replacement.lua" })
  attached = {}
  picker.action(composer, "searcher: change root to parent")()
  t.assert_eq(Paths.key(root), composer._uuid_root)
  t.assert_same({ root }, attached)
end)

t:test("expansion actions typed ahead act on the tree their earlier actions produce", function()
  local composer = fixture()
  local tree = composer._treeview
  local reports = bootstrap.with_reporter(t)
  local dir = Paths.key(root .. "/dir")
  local open, collapse = picker.action(composer, "searcher: open"), picker.action(composer, "searcher: collapse")
  composer.result:set_lnum_current(tree:retrieve_lnum(dir))
  treeview.await(tree:ready())
  treeview.assert_typed_ahead(t, tree, dir, open, collapse)
  t.assert_eq(0, #reports.error, vim.inspect(reports.error))
end)

t:test("preview treats an empty result as a normal state", function()
  local basic_props = nil ---@type era.m.searcher.composer.IBasicProps|nil
  local original_new = era.m.searcher.BasicComposer.new
  t:patch_table(era.m.searcher.BasicComposer, "new", function(props)
    basic_props = props
    return original_new(props)
  end)

  local composer = picker.searcher(t, {
    name = "empty-preview",
    permanent = false,
    preview = true,
    title = "file-search test",
    rootpath = t:tempdir(),
  })
  picker.show_result(composer, 80, 10)
  treeview.await(composer._treeview:ready())

  local bufnr = t:buffer({ "stale preview" })
  ---@diagnostic disable-next-line: undefined-field
  assert(basic_props ~= nil and basic_props.render_preview ~= nil, "preview renderer should be captured")
  composer._last_preview_filepath = "stale.lua"
  ---@diagnostic disable-next-line: duplicate-set-field
  composer.__retrieve_nodeuuid__ = function()
    return nil, 0
  end

  ---@diagnostic disable-next-line: undefined-field
  local result = basic_props.render_preview(bufnr, false)
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
  ---@diagnostic disable-next-line: undefined-field
  result = basic_props.render_preview(bufnr, false)
  t.assert_eq("Unknown lnum(-1)", result.title, "invalid nonzero line remains diagnostic")
end)

t:test("era.m.searcher.composer.filetree resolves a published parent identity for collapse", function()
  local tree = picker.branch_tree(t)
  treeview.applied(tree:publish({ mode = "tree", rootuuid = "root" }))
  local composer = setmetatable({ _treeview = tree }, { __index = require("era.m.searcher.composer.filetree") })
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

t:test("era.m.searcher.composer.filetree navigates from a List location to its displayed file", function()
  local tree = picker.branch_tree(t)
  tree:insert("one", {
    nodetype = "leaf",
    locations = { { nodetype = "location", leafuuid = "one", locationuuid = "one:1", lnum = 1 } },
  })
  treeview.applied(tree:publish({ mode = "list", rootuuid = "root", orders = { "one" } }))
  local composer = setmetatable({ _treeview = tree }, { __index = require("era.m.searcher.composer.filetree") })
  local row, key = composer:__retrieve_lnum_parent__("one:1")
  t.assert_eq(1, row)
  t.assert_eq("one", key)
end)

t:run()
