require("ark.bootstrap").setup()
local t = require("__test__.support.harness").new()
local treeview = require("__test__.support.treeview")
local Paths = require("era.view.result_paths")
local Files = require("era.view.result_files")

---@return era.m.picker.FiletreeView
local function fixture()
  local view = Files.new({ name = "file result test", tree = Paths.new() })
  t:defer(function()
    view:dispose()
  end)
  view:reset_filepaths("/workspace", { "dir/one.lua", "two.lua" }, false)
  treeview.publish(view, { rootuuid = Paths.key("/workspace") })
  return view
end

for _, directory in ipairs({ false, true }) do
  t:test("inserting a " .. (directory and "directory" or "file") .. " preserves native ancestor state", function()
    local view = fixture()
    local key = Paths.key("/workspace/dir")
    view:collapse(key, "collapse", false)
    view:toggle_select(key, true, true)
    treeview.publish(view)
    if directory then
      view:insert_dirpath("/workspace/dir/new")
    else
      view:insert_filepath("/workspace/dir/new.lua", false)
    end
    treeview.publish(view)
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
  treeview.publish(view, { only_selected = true })
  t.assert_true(view:isselected(key))
  t.assert_true(view:retrieve_lnum(key) ~= nil)
end)

t:test("reset restores native location identities and selection", function()
  local view = fixture()
  view:reset_filepaths("/workspace", { "dir/one.lua:4:2", "dir/one.lua:9:3" }, true)
  treeview.publish(view)
  local key = Paths.key("/workspace/dir/one.lua")
  local before = view:retrieve(key).locations
  t.assert_eq(2, #before)
  view:toggle_select(key, true, true)
  treeview.publish(view)
  view:reset_filepaths("/workspace", { "dir/one.lua:4:2", "dir/one.lua:9:3" }, true)
  treeview.publish(view, { mode = "list", only_selected = true })
  t.assert_true(view:isselected(key))
  t.assert_true(view:isselected(before[1].locationuuid))
  t.assert_eq(3, view:linecount(), "List membership excludes directory ancestors")
end)

t:test("search membership is projected through native ancestors", function()
  local view = fixture()
  local orders = view:match({
    rootuuid = Paths.key("/workspace"),
    pattern = "one.lua",
    fuzzy = false,
    regex = false,
    case_sensitive = false,
  }) --[[@as yoz.fuzzy.Result]]
  t.assert_same({ Paths.key("/workspace/dir/one.lua") }, orders:keys())
  treeview.publish(view, { rootuuid = Paths.key("/workspace"), only_matched = true, orders = orders })
  t.assert_eq(2, view:linecount())
  t.assert_eq(Paths.key("/workspace/dir"), view:retrieve_uuid(1))
  t.assert_eq(Paths.key("/workspace/dir/one.lua"), view:retrieve_uuid(2))
end)

t:test("fuzzy matches rank root-relative paths and keep their identity while unchanged", function()
  local view = fixture()
  view:reset_filepaths("/workspace", { "src/alpha.lua", "lib/alpha_test.lua", "alpha.lua", "notes.md" }, false)
  local root = Paths.key("/workspace")
  local params =
    { rootuuid = root, pattern = "alpha", fuzzy = true, regex = false, case_sensitive = false, scheme = "path" }
  local orders = view:match(params) --[[@as yoz.fuzzy.Result]]
  local expected = {
    Paths.key("/workspace/alpha.lua"),
    Paths.key("/workspace/src/alpha.lua"),
    Paths.key("/workspace/lib/alpha_test.lua"),
  }
  t.assert_same(expected, orders:keys(), vim.inspect(orders:keys()))
  t.assert_true(rawequal(orders, view:match(params)), "an unchanged result keeps its identity")
  treeview.publish(view, { mode = "list", rootuuid = root, orders = orders })
  t.assert_eq(expected[1], view:retrieve_uuid(1))
  t.assert_eq(3, view:linecount())
  -- The root's own path is not matched: every file lies under "workspace".
  t.assert_eq(0, view:match(vim.tbl_extend("force", params, { pattern = "workspace" })):count())
end)

t:test("fuzzy highlights map root-relative positions onto displayed path columns", function()
  local view = fixture()
  local root = Paths.key("/workspace")
  local key = Paths.key("/workspace/dir/one.lua")
  view:match({
    rootuuid = root,
    pattern = "dione",
    fuzzy = true,
    regex = false,
    case_sensitive = false,
    scheme = "path",
  })
  local frame =
    treeview.publish(view, { mode = "list", rootuuid = root, orders = view._result, list_text = "ancestry" })
  local spans = {}
  t:patch_table(vim.api, "nvim_buf_set_extmark", function(_, _, _, col, options)
    if options.hl_group == "TreeviewMatch" then
      spans[#spans + 1] = { col, options.end_col }
    end
    return 0
  end)
  local bufnr = vim.api.nvim_create_buf(false, true)
  t:defer(function()
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end)
  view:decorate_row({ bufnr = bufnr }, frame, 0, frame:source():id(key), 10, "dir/one.lua", false)
  t.assert_same({ { 10, 12 }, { 14, 17 } }, spans)
end)

t:test("highlights follow the latest query while unchanged orders keep their identity", function()
  local view = fixture()
  local root = Paths.key("/workspace")
  local key = Paths.key("/workspace/dir/one.lua")
  local params =
    { rootuuid = root, pattern = "on", fuzzy = true, regex = false, case_sensitive = false, scheme = "path" }
  local orders = view:match(params)
  local frame = treeview.publish(view, { mode = "list", rootuuid = root, orders = orders, list_text = "ancestry" })
  t.assert_true(rawequal(orders, view:match(vim.tbl_extend("force", params, { pattern = "one" }))))
  local spans = {}
  t:patch_table(vim.api, "nvim_buf_set_extmark", function(_, _, _, col, options)
    if options.hl_group == "TreeviewMatch" then
      spans[#spans + 1] = { col, options.end_col }
    end
    return 0
  end)
  local bufnr = vim.api.nvim_create_buf(false, true)
  t:defer(function()
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end)
  view:decorate_row({ bufnr = bufnr }, frame, 0, frame:source():id(key), 0, "dir/one.lua", false)
  t.assert_same({ { 4, 7 } }, spans)
end)

t:test("regex matches list each file once however often it matches", function()
  local view = fixture()
  -- A pattern with a newline reports each occurrence as its own line match.
  local keys = view:match({
    rootuuid = Paths.key("/workspace"),
    pattern = "o|\n",
    fuzzy = false,
    regex = true,
    case_sensitive = false,
  })
  t.assert_same({ Paths.key("/workspace/dir/one.lua"), Paths.key("/workspace/two.lua") }, keys)
end)

t:test("a plain file is never treated as a collapsed branch", function()
  local view = fixture()
  t.assert_false(view:retrieve(Paths.key("/workspace/two.lua")).collapsed)
  view:add_location(Paths.key("/workspace/two.lua"), { lnum = 3, col = 1 })
  treeview.publish(view)
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
  treeview.publish(view, { rootuuid = root })
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
  t.assert_same(expected, paths)
  view:insert_filepath("/workspace/src/0.lua", false)
  treeview.publish(view, { rootuuid = root })
  t.assert_eq(Paths.key("/workspace/src/0.lua"), view:retrieve_uuid(4))
  local orders = { Paths.key("/workspace/z.lua"), Paths.key("/workspace/src/a.lua") }
  treeview.publish(view, { mode = "list", rootuuid = root, orders = orders })
  t.assert_eq(orders[1], view:retrieve_uuid(1))
  t.assert_eq(orders[2], view:retrieve_uuid(2))
end)

t:run()
