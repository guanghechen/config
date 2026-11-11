require("ark.bootstrap").setup()
local bootstrap = require("__test__.support.bootstrap")
local picker = require("__test__.support.picker")
local t = require("__test__.support.harness").new()
local treeview = require("__test__.support.treeview")
local Source = require("era.view.result_source")
local Composer = require("era.m.picker.composer.tree")

---@return era.m.picker.TreeComposer
local function fixture()
  local source = Source.new("root", { name = "root" })
  local view = picker.result_tree(t, "symbols", source, function(_, data)
    return { label = data.name }
  end)
  return setmetatable({
    fullname = "symbols",
    _disposed = false,
    _tree = source,
    _treeview = view,
    _node_sorter = function(a, b)
      return a.name < b.name
    end,
    _scheduler_match = { schedule = function() end },
    _on_attached = function() end,
  }, Composer)
end

---@param composer                      era.m.picker.TreeComposer
---@return nil
local function publish(composer)
  composer._tree:walk(nil, function(key, data)
    composer._treeview:insert(key, {
      nodetype = #composer._tree:children(key) > 0 and "container" or "leaf",
      text = data.name,
    })
  end)
  treeview.publish(composer._treeview)
end

t:test("symbol insertion preserves source order in native rows", function()
  local composer = fixture()
  composer:insert("root", "second", { name = "z" })
  composer:insert("root", "first", { name = "a" })
  publish(composer)
  t.assert_eq("first", composer._treeview:retrieve_uuid(1))
  t.assert_eq("second", composer._treeview:retrieve_uuid(2))
end)

t:test("reparenting a symbol preserves its native selection", function()
  local composer = fixture()
  composer:insert("root", "left", { name = "left" })
  composer:insert("root", "right", { name = "right" })
  composer:insert("left", "leaf", { name = "leaf" })
  publish(composer)
  composer._treeview:toggle_select("leaf", true, false)
  treeview.publish(composer._treeview)
  composer:insert("right", "leaf", { name = "leaf" })
  publish(composer)
  t.assert_true(composer._treeview:isselected("leaf"))
  local frame = composer._treeview:frame()
  local leaf = frame:source():id("leaf")
  t.assert_eq(frame:source():id("right"), frame:node(leaf).parent)
end)

t:test("attach rejects unknown roots and publishes known symbol roots", function()
  local composer = fixture()
  local reports = bootstrap.with_reporter(t)
  composer:attach("absent")
  t.assert_eq(1, #reports.error)
  t.assert_nil(composer._uuid_root)
  composer:insert("root", "scope", { name = "scope" })
  composer:insert("scope", "symbol", { name = "symbol" })
  publish(composer)
  composer:attach("scope")
  treeview.publish(composer._treeview, { rootuuid = composer._uuid_root })
  t.assert_eq("symbol", composer._treeview:retrieve_uuid(1))
end)

---@param name                          string
---@return era.m.picker.TreeComposer
local function action_fixture(name)
  local composer = Composer.new(picker.tree_props({
    name = name,
    permanent = false,
    title = "symbols",
    node_sorter = function(a, b)
      return a.name < b.name
    end,
    present = function(_, data)
      return { label = data and data.name or "root" }
    end,
  }))
  t:defer(function()
    vim.cmd.normal({ args = { vim.keycode("<Esc>") }, bang = true })
    composer:dispose()
  end)
  t:patch_table(composer._scheduler_match, "schedule", function() end)
  return composer
end

---@param composer                      era.m.picker.TreeComposer
---@return nil
local function mount(composer)
  picker.show_result(composer, 60, 8)
  treeview.await(composer.result.draw())
  treeview.await(composer._treeview:ready())
end

t:test("TreeComposer hide captures native Visual rows and rejects a desynced surface", function()
  local composer = action_fixture("guarded-symbols")
  local tree = composer._treeview
  composer:insert(composer._tree.root, "scope", { name = "scope" })
  composer:insert("scope", "one", { name = "one" })
  composer:insert("scope", "two", { name = "two" })
  tree:insert("scope", { nodetype = "container" })
  tree:insert("one", { nodetype = "leaf" })
  tree:insert("two", { nodetype = "leaf" })
  mount(composer)
  local hide = picker.action(composer, "tree: mark the node invisible")
  local winnr = composer.result:get_winnr()
  vim.api.nvim_set_current_win(winnr)
  vim.api.nvim_win_set_cursor(winnr, { tree:retrieve_lnum("scope"), 0 })
  tree.view._desynced = true
  hide()
  t.assert_nil(next(tree._hidden))
  tree.view._desynced = false
  vim.cmd.normal({ args = { "Vj" }, bang = true })
  hide()
  t.assert_false(tree:isvisible("scope"))
  t.assert_false(tree:isvisible("one"))
  t.assert_true(tree:isvisible("two"), "Visual range must not expand to the container's whole subtree")
  t.assert_eq("n", vim.fn.mode())
  composer._tree:remove("two")
  composer.result:set_lnum_current(tree:retrieve_lnum("two"))
  picker.action(composer, "tree: change root")()
  t.assert_eq("two", composer._uuid_root, "attachment checks the displayed node's membership")
  t.assert_true(pcall(composer.__toggle_node__, composer, "two", false, false))
end)

t:test("expansion actions typed ahead act on the tree their earlier actions produce", function()
  local composer = action_fixture("typeahead-symbols")
  local tree = composer._treeview
  composer:insert(composer._tree.root, "scope", { name = "scope" })
  composer:insert("scope", "one", { name = "one" })
  composer:insert("scope", "two", { name = "two" })
  tree:insert("scope", { nodetype = "container" })
  tree:insert("one", { nodetype = "leaf" })
  tree:insert("two", { nodetype = "leaf" })
  mount(composer)
  local reports = bootstrap.with_reporter(t)
  local open, collapse = picker.action(composer, "tree: open"), picker.action(composer, "tree: collapse")
  composer.result:set_lnum_current(tree:retrieve_lnum("scope"))
  treeview.await(tree:ready())
  treeview.assert_typed_ahead(t, tree, "scope", open, collapse)
  t.assert_eq(0, #reports.error, vim.inspect(reports.error))
end)

t:test("a subtree with deep LSP identities hides completely across the native byte boundary", function()
  local composer = action_fixture("deep-symbol-identities")
  local tree, source = composer._treeview, composer._tree
  local parent = source.root
  for depth = 1, 300 do
    local key = parent .. ":" .. depth
    source:insert(parent, key, { name = "scope" })
    tree:insert(key, { nodetype = "container" })
    if depth == 300 then
      composer._uuid_root = parent
    end
    parent = key
  end
  local expected = { parent }
  for index = 1, 1024 do
    local key = parent .. ":" .. (index + 300)
    source:insert(parent, key, { name = "leaf" })
    tree:insert(key, { nodetype = "leaf" })
    expected[#expected + 1] = key
  end
  mount(composer)
  t.assert_eq(1025, tree:linecount())
  t.assert_true(#parent > 1024)
  local dirty = 0
  t:patch_table(composer._composer, "mark_result_dirty", function()
    dirty = dirty + 1
  end)
  local reports = bootstrap.with_reporter(t)
  picker.action(composer, "tree: mark the subroot invisible")()
  t.assert_eq(0, #reports.error, vim.inspect(reports.error))
  t.assert_eq(1, dirty)
  for _, key in ipairs(expected) do
    t.assert_false(tree:isvisible(key))
  end
  treeview.await(composer.result.draw())
  treeview.await(tree:ready())
  t.assert_eq(0, tree:linecount(), "the successful hide must reach the published projection")
end)

for _, description in ipairs({ "tree: mark the node invisible", "tree: mark the subroot invisible" }) do
  t:test(description .. " leaves visibility and revision unchanged when a later page fails", function()
    local composer = action_fixture("failed-hide-page")
    local tree, source = composer._treeview, composer._tree
    source:insert(source.root, "scope", { name = "scope" })
    tree:insert("scope", { nodetype = "container" })
    for index = 1, 2500 do
      local key = "leaf-" .. index
      source:insert("scope", key, { name = "leaf" })
      tree:insert(key, { nodetype = "leaf" })
    end
    tree:mark_node_invisible("previously-hidden")
    mount(composer)
    local hidden, revision = tree._hidden, tree._revision
    local pages, dirty = 0, 0
    local original = tree.iter_rows
    t:patch_table(tree, "iter_rows", function(self, frame, first, last)
      local proxy = setmetatable({}, {
        __index = function(_, name)
          return function(_, ...)
            if name == "row_keys" then
              pages = pages + 1
              if pages == 2 then
                error("injected page failure", 0)
              end
            end
            return frame[name](frame, ...)
          end
        end,
      })
      return original(self, proxy, first, last)
    end)
    t:patch_table(composer._composer, "mark_result_dirty", function()
      dirty = dirty + 1
    end)
    local reports = bootstrap.with_reporter(t)
    picker.action(composer, description)()
    t.assert_eq(2, pages)
    t.assert_same(
      { "injected page failure" },
      vim.tbl_map(function(report)
        return report.message
      end, reports.error)
    )
    t.assert_true(hidden == tree._hidden)
    t.assert_same({ ["previously-hidden"] = true }, tree._hidden)
    t.assert_eq(revision, tree._revision)
    t.assert_eq(0, dirty)
    t.assert_nil(tree.view._submission)
  end)
end

t:test("Tab toggles the selection from the finder while a filter is being typed", function()
  local composer = action_fixture("finder-tab")
  local tab ---@type stl.t.IKeymap|nil
  for _, keymap in ipairs(composer.finder.keymaps) do
    if keymap.key == "<Tab>" then
      tab = keymap
    end
  end
  t.assert_eq("tree: toggle selection", tab and tab.desc, "finder Tab")
  t.assert_true(vim.list_contains(tab and tab.modes or {}, "i"), "Insert mode, like Normal mode and the result pane")
end)

t:test("confirming in a picker that closes for good reports the node", function()
  local composer = action_fixture("confirm-closes")
  composer:insert(composer._tree.root, "one", { name = "one" })
  composer._treeview:insert("one", { nodetype = "leaf" })
  mount(composer)
  local confirmed = nil ---@type string[]|nil
  t:patch_table(composer, "_on_confirm", function(_, uuids)
    confirmed = uuids
  end)

  composer:__resolve_confirmation__("one")
  t.assert_same({ "one" }, confirmed)
  t.assert_true(composer._composer:isdisposed(), "a picker that is not permanent closes for good")
end)

---Open a permanent picker over the given nodes in a child UI, showing all three rows matched.
---@param viewtype                      string
---@param nodes                         string[][] Key, parent key ("" for the root) and nodetype of each node.
---@return __test__.support.UI
local function open_typed_ahead(viewtype, nodes)
  local ui = require("__test__.support.ui").open(t, { width = 100, height = 32, runtime = "ark" })
  ui:lua(
    [[
    local viewtype, nodes = ...
    confirmed = nil
    picker = era.m.picker.TreeComposer.new(require("__test__.support.picker").tree_props({
      name = "typed ahead", title = "typed ahead", permanent = true,
      present = function(_, data) return { label = data and data.name or "" } end,
      node_sorter = function(a, b) return a.name < b.name end,
      flag_fuzzy = true, flag_case_sensitive = false, flag_viewtype = viewtype,
      on_confirm = function(composer, uuids)
        confirmed = uuids and uuids[1] or false
        composer:close()
      end,
    }))
    local root = picker._tree.root
    for _, node in ipairs(nodes) do
      local key, parent, nodetype = unpack(node)
      picker:insert(parent == "" and root or parent, key, { name = key })
      picker._treeview:insert(key, { nodetype = nodetype, text = key })
    end
    picker:attach(root)
    picker._scheduler_match:schedule({ immediate = true })
    picker:mark_result_dirty()
    picker:focus()
  ]],
    viewtype,
    nodes
  )
  ui:wait_lua("return picker._treeview:linecount() == 3 and not picker._scheduler_match:pending()", 5000, "three rows")
  return ui
end

t:test("a query typed ahead of <CR> confirms from its own results", function()
  local ui = open_typed_ahead("list", { { "alpha", "", "leaf" }, { "beta", "", "leaf" }, { "gamma", "", "leaf" } })
  -- One burst, as keys typed faster than the match debounce arrive: <CR> runs before the query is matched.
  ui:rpc("nvim_input", "igam<CR>")
  ui:wait_lua("return confirmed ~= nil", 5000, "confirmed")
  t.assert_eq("gamma", ui:lua("return confirmed"))
end)

t:test("keys typed after a deferred <CR> leave its query", function()
  local ui =
    open_typed_ahead("tree", { { "scope", "", "container" }, { "one", "scope", "leaf" }, { "two", "scope", "leaf" } })
  -- <CR> waits for the collapse <C-h> submits, then opens scope again; zz reaches the input before it runs.
  ui:rpc("nvim_input", "i<C-h><CR>zz")
  ui:wait_lua(
    "return picker._matched_input == 'zz' and not picker._treeview:retrieve('scope').collapsed",
    5000,
    "scope opened again"
  )
end)

t:run()
