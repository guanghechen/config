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
  local bufnr = t:buffer()
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
  local bufnr = t:buffer()
  view:decorate_row({ bufnr = bufnr }, frame, 0, frame:source():id(key), 0, "dir/one.lua", false)
  t.assert_same({ { 4, 7 } }, spans)
end)

t:test("regex matches list each file once however often it matches", function()
  local view = fixture()
  -- Each file is one corpus item, listed once whatever the pattern matches in it.
  local orders = view:match({
    rootuuid = Paths.key("/workspace"),
    pattern = "o|\n",
    fuzzy = false,
    regex = true,
    case_sensitive = false,
  })
  t.assert_same({ Paths.key("/workspace/dir/one.lua"), Paths.key("/workspace/two.lua") }, orders:keys())
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

t:test("location spans are prepared for the viewport and metadata-only updates reach both surfaces", function()
  local ui = require("__test__.support.ui").open(t, { width = 120, height = 30, runtime = "ark" })
  ui:lua([[
    treeview = require("__test__.support.treeview")
    local Paths = require("era.view.result_paths")
    local Files = require("era.view.result_files")
    spans, errors, formats = {}, {}, 0
    stl.reporter.error = function(value) errors[#errors+1] = value.message end
    vim.api.nvim_set_hl(0, "LocationOld", {fg="#ff0000"})
    vim.api.nvim_set_hl(0, "LocationNew", {fg="#00ff00"})
    local format = Files.present_location
    Files.present_location = function(...)
      formats = formats + 1
      return format(...)
    end
    local mark = vim.api.nvim_buf_set_extmark
    vim.api.nvim_buf_set_extmark = function(bufnr, namespace, row, col, opts)
      if opts.ephemeral and (opts.hl_group == "LocationOld" or opts.hl_group == "LocationNew") then
        spans[bufnr] = spans[bufnr] or {}
        spans[bufnr][row] = {col=col, last=opts.end_col, highlight=opts.hl_group}
      end
      return mark(bufnr, namespace, row, col, opts)
    end
    owner = Files.new({name="location viewport", tree=Paths.new()})
    owner:reset_filepaths("/location-viewport", {"many.lua"})
    file_key = Paths.key("/location-viewport/many.lua")
    for index=1,2000 do
      owner:add_location(file_key, {
        locationuuid="match:" .. index, lnum=index, col=1, text="needle",
        highlights={{coll=0, colr=6, hlname="LocationOld"}},
      })
    end
    request = {mode="tree", rootuuid=Paths.key("/location-viewport")}
    treeview.publish(owner, request)
    assert(formats == 0, "offscreen records must not prepare highlight spans")
    local frame = owner:frame()
    assert(frame:node(frame:source():id("match:1000")).fields.highlights == nil)
    main_bufnr = vim.api.nvim_create_buf(false, true)
    local winnr = vim.api.nvim_open_win(main_bufnr, false, {relative="editor",row=0,col=0,width=50,height=6})
    owner:mount(winnr, main_bufnr, function() end)
    treeview.await(owner:ready())
    preview = era.view.PickerPreview.new({
      name="location preview", diagnostic_scope="location preview", relative_number=false, keymaps={},
      tree=function() return {owner=owner,key=file_key,foldempty=false,title="locations"} end,
      draw=function() error("expected a native location preview") end,
    })
    preview:create_win({border="none",winhighlight=""},{row=0,col=60,width=50,height=6})
    preview:mark_content_dirty()
  ]])
  ui:wait_lua(
    [[
      local other = preview:get_bufnr()
      return spans[main_bufnr] and spans[main_bufnr][1] and spans[other] and spans[other][0] or false
    ]],
    5000,
    "both surfaces drew the spans"
  )
  local initial = ui:lua("return {formats=formats,main=spans[main_bufnr][1],preview=spans[preview:get_bufnr()][0]}")
  t.assert_true(initial.formats < 500, "only visible locations should be formatted")
  t.assert_eq("LocationOld", initial.main.highlight)
  t.assert_eq(6, initial.main.last - initial.main.col)
  t.assert_eq("LocationOld", initial.preview.highlight)

  ui:lua([[
    previous = owner:retrieve("match:1")
    revision = owner:frame():header().data_revision
    owner.entries["match:1"].highlights = {{coll=1,colr=4,hlname="LocationNew"}}
    owner:invalidate()
    local prepare = owner.view._options.prepare_frame
    owner.view._options.prepare_frame = function(...)
      if not released then
        return stl.c.Future.new(function(resolve) release = resolve end)
      end
      return prepare(...)
    end
    publication = owner:publish(vim.deepcopy(request))
  ]])
  ui:wait_lua("return release ~= nil", 5000, "viewport preparation held")
  t.assert_false(ui:lua("return publication:is_done()"), "publication waits for viewport preparation")
  ui:lua("released=true; release(function() end)")
  ui:wait_lua(
    [[
      return publication:is_done() and spans[main_bufnr][1].highlight == "LocationNew"
        and spans[preview:get_bufnr()][0].highlight == "LocationNew"
    ]],
    5000,
    "the new spans reached both surfaces"
  )
  local result = ui:lua([[
    assert(not publication:is_failed(), publication:get_error())
    return {main=spans[main_bufnr][1],preview=spans[preview:get_bufnr()][0],
      unchanged=owner:frame():header().data_revision == revision,old=previous.highlights[1].hlname,errors=errors}
  ]])
  t.assert_true(result.unchanged, "location spans need no native record mutation")
  t.assert_eq("LocationOld", result.old, "the prior metadata snapshot remains immutable")
  t.assert_eq(3, result.main.last - result.main.col)
  t.assert_eq(3, result.preview.last - result.preview.col)
  t.assert_eq(0, #result.errors, vim.inspect(result.errors))

  ui:lua([[
    local prepare = preview._tree_view._options.prepare_frame
    preview._tree_view._options.prepare_frame = function(...)
      return prepare(...):then_(function(commit)
        if not preview_released then
          return stl.c.Future.new(function(resolve)
            release_preview = function() resolve(commit) end
          end)
        end
        return commit
      end)
    end
    owner.entries["match:1"].text = "updated needle"
    owner:invalidate()
    publication = owner:publish(vim.deepcopy(request))
  ]])
  ui:wait_lua("return publication:is_done() and release_preview ~= nil", 5000, "the preview publication held")
  t.assert_true(
    ui:lua([[
    local shown = preview._tree_view:frame():header().data_revision
    assert(shown ~= owner:frame():header().data_revision)
    return owner._versions[shown] ~= nil
  ]]),
    "a lagging preview retains its displayed metadata"
  )
  ui:lua([[
    spans[preview:get_bufnr()] = {}
    vim.api.nvim__redraw({win=preview:get_winnr(),valid=false})
  ]])
  ui:wait_lua("return spans[preview:get_bufnr()][0] ~= nil", 5000, "the lagging preview redrew")
  ui:lua("preview_released=true; release_preview()")
  ui:wait_lua(
    "return vim.tbl_count(owner._versions) == 1",
    5000,
    "obsolete preview metadata is reclaimed after its replacement publishes"
  )
end)

t:run()
