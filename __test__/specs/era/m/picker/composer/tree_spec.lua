require("ark.bootstrap").setup()
local t = require("__test__.support.harness").new()
local treeview = require("__test__.support.treeview")
local Source = require("era.view.result_source")
local View = require("era.view.result_tree")
local Composer = require("era.m.picker.composer.tree")

---@return era.m.picker.TreeComposer
local function fixture()
  local source = Source.new("root", { name = "root" })
  local view = View.new({
    name = "symbols",
    tree = source,
    present = function(_, data)
      return { label = data.name }
    end,
  })
  local composer = setmetatable({
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
  t:defer(function()
    view:dispose()
  end)
  return composer
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
  local errors = {}
  t:patch_table(stl.reporter, "error", function(value)
    errors[#errors + 1] = value
  end)
  composer:attach("absent")
  t.assert_eq(1, #errors)
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
  local observable = stl.c.Observable.from_value
  local composer = Composer.new({
    name = name,
    permanent = false,
    title = "symbols",
    search_pattern = observable(""),
    flag_foldempty = observable(false),
    flag_fuzzy = observable(false),
    flag_regex = observable(false),
    flag_case_sensitive = observable(true),
    flag_selected = observable(false),
    flag_viewtype = observable("tree"),
    node_sorter = function(a, b)
      return a.name < b.name
    end,
    present = function(_, data)
      return { label = data and data.name or "root" }
    end,
  })
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
  composer.result:create_win({ border = "none", number = false, winhighlight = "" }, {
    row = 0,
    col = 0,
    width = 60,
    height = 8,
  })
  treeview.await(composer.result.draw())
  treeview.await(composer._treeview:ready())
end

---@param composer                      era.m.picker.TreeComposer
---@param description                   string
---@return fun(): nil
local function action(composer, description)
  for _, keymap in ipairs(composer.result.keymaps) do
    if keymap.desc == description then
      return keymap.callback
    end
  end
  error("missing action: " .. description)
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
  local hide = action(composer, "tree: mark the node invisible")
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
  for _, keymap in ipairs(composer.result.keymaps) do
    if keymap.desc == "tree: change root" then
      keymap.callback()
      break
    end
  end
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
  local errors = {} ---@type table[]
  t:patch_table(stl.reporter, "error", function(value)
    errors[#errors + 1] = value
  end)
  local open, collapse = action(composer, "tree: open"), action(composer, "tree: collapse")
  composer.result:set_lnum_current(tree:retrieve_lnum("scope"))
  treeview.await(tree:ready())
  treeview.assert_typed_ahead(t, tree, "scope", open, collapse)
  t.assert_eq(0, #errors, vim.inspect(errors))
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
  local dirty, failures = 0, {}
  t:patch_table(composer._composer, "mark_result_dirty", function()
    dirty = dirty + 1
  end)
  t:patch_table(stl.reporter, "error", function(value)
    failures[#failures + 1] = value.message
  end)
  action(composer, "tree: mark the subroot invisible")()
  t.assert_eq(0, #failures, vim.inspect(failures))
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
    local pages, dirty, failures = 0, 0, {}
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
    t:patch_table(stl.reporter, "error", function(value)
      failures[#failures + 1] = value.message
    end)
    action(composer, description)()
    t.assert_eq(2, pages)
    t.assert_same({ "injected page failure" }, failures)
    t.assert_true(hidden == tree._hidden)
    t.assert_same({ ["previously-hidden"] = true }, tree._hidden)
    t.assert_eq(revision, tree._revision)
    t.assert_eq(0, dirty)
    t.assert_nil(tree.view._submission)
  end)
end

t:run()
t:run()
