require("ark.bootstrap").setup()
local t = require("__test__.support.harness").new()
local treeview = require("__test__.support.treeview")
local Paths = require("era.view.result_paths")
local root = "/workspace/searcher-actions"

---@param value                         any
---@return stl.c.Observable
local function observable(value)
  return stl.c.Observable.from_value(value)
end

---@param on_attached                   ?era.m.searcher.composer.filetree.IOnAttached
---@param frecency                      ?stl.c.Frecency
---@return era.m.searcher.FiletreeComposer
local function fixture(on_attached, frecency)
  local composer = era.m.searcher.FiletreeComposer.new({
    name = "published-actions",
    permanent = false,
    preview = false,
    title = "published actions",
    excludes = observable({}),
    flag_exclude = observable(false),
    flag_foldempty = observable(false),
    flag_gitignore = observable(false),
    flag_limit_matches = observable(true),
    flag_regex = observable(false),
    flag_replace = observable(false),
    flag_case_sensitive = observable(true),
    flag_selected = observable(false),
    flag_viewtype = observable("tree"),
    includes = observable({ "*.lua" }),
    max_filesize = observable("1M"),
    max_matches = observable(100),
    replace_pattern = observable(""),
    rootpath = observable(root),
    search_pattern = observable(""),
    on_attached = on_attached,
    frecency = frecency,
  })
  t:defer(function()
    vim.cmd.normal({ args = { vim.keycode("<Esc>") }, bang = true })
    composer:dispose()
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
  end
  composer.result:create_win({ border = "none", number = false, winhighlight = "" }, {
    row = 0,
    col = 0,
    width = 60,
    height = 12,
  })
  treeview.await(composer.result.draw())
  treeview.await(tree:ready())
  composer._published_search_inputs = composer:__snapshot_search_inputs__()
  t.assert_true(composer:__is_search_projection_current__())
  t.assert_true(tree.view:_valid())
  return composer
end

---@param composer                      era.m.searcher.FiletreeComposer
---@param description                   string
---@return fun(): nil
local function action(composer, description)
  for _, keymaps in ipairs({ composer.result.keymaps, composer.finder.keymaps }) do
    for _, keymap in ipairs(keymaps) do
      if keymap.desc == description then
        return keymap.callback
      end
    end
  end
  error("missing action: " .. description)
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
  local result_winnr = assert(composer.result:get_winnr())
  vim.api.nvim_set_current_win(result_winnr)
  -- A float opened with the intended offset from the same cursor gives the expected placement.
  local reference = vim.api.nvim_open_win(vim.api.nvim_create_buf(false, true), false, {
    relative = "cursor",
    row = 1,
    col = 4,
    width = 1,
    height = 1,
  })
  local expected = vim.api.nvim_win_get_config(reference)
  vim.api.nvim_win_close(reference, true)

  action(composer, "searcher: copy filepath")()
  local popup = vim.api.nvim_get_current_win() ---@type integer
  t:defer(function()
    if vim.api.nvim_win_is_valid(popup) then
      vim.api.nvim_win_close(popup, true)
    end
  end)

  t.assert_eq(stl.e.WinTypeEnum.SELECT, vim.w[popup].wintype, "the copy choices")
  local config = vim.api.nvim_win_get_config(popup)
  t.assert_eq(expected.relative, config.relative, "relative to the cursor")
  t.assert_eq(result_winnr, config.win, "anchored to the result window")
  t.assert_eq(expected.row, config.row, "one row below the cursor")
  t.assert_eq(expected.col, config.col, "four columns right of the cursor")
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
  action(composer, "searcher: send to qflist")()
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
  action(composer, "searcher: add to ai")()
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
  action(composer, "searcher: mark the node invisible")()
  action(composer, "searcher: mark the subroot invisible")()
  action(composer, "searcher: replace all files")()
  action(composer, "search: replace file")()
  t.assert_nil(next(tree._hidden))
  t.assert_eq(0, replacements)
  tree.view._desynced = false
  action(composer, "searcher: replace all files")()
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
  local replace = action(composer, "search: replace file")
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
  t:patch_table(yoz.replace, "replace_file", function(options)
    replacements[#replacements + 1] = options.filepath
    return true
  end)
  action(composer, "searcher: replace all files")()
  t.assert_eq(3, #replacements)
  t.assert_nil(tree.entries[key].locations)
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
  action(composer, "searcher: change root")()
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
  action(composer, "searcher: change root to parent")()
  t.assert_eq(Paths.key(root), composer._uuid_root)
  t.assert_same({ root }, attached)
end)

t:test("expansion actions typed ahead act on the tree their earlier actions produce", function()
  local composer = fixture()
  local tree = composer._treeview
  local errors = {} ---@type table[]
  t:patch_table(stl.reporter, "error", function(value)
    errors[#errors + 1] = value
  end)
  local dir = Paths.key(root .. "/dir")
  local open, collapse = action(composer, "searcher: open"), action(composer, "searcher: collapse")
  composer.result:set_lnum_current(tree:retrieve_lnum(dir))
  treeview.await(tree:ready())
  treeview.assert_typed_ahead(t, tree, dir, open, collapse)
  t.assert_eq(0, #errors, vim.inspect(errors))
end)

t:run()
