---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.specs.era.view.result_tree" ---@type string

local t = require("__test__.support.harness").new("era.view.result_tree")
local bootstrap = require("__test__.support.bootstrap")
local suffix = vim.uv.os_uname().sysname == "Darwin" and "dylib" or "so"
bootstrap.with_yoz(t, assert(package.loadlib("rust/target/debug/libyoz." .. suffix, "luaopen_yoz"))())
local errors = {}
bootstrap.with_stl(t, {
  c = { Future = require("stl.c.future") },
  nvim = { fn = require("stl.nvim.fn") },
  reporter = {
    error = function(value)
      errors[#errors + 1] = value.message
    end,
  },
})
local Source = require("era.view.result_source")
local Tree = require("era.view.result_tree")

---@param future                        stl.c.Future
---@return table
local function await(future)
  t.wait_until(function()
    return future:is_done()
  end, 5000, "result publication did not finish: " .. vim.inspect(errors))
  t.assert_false(future:is_failed(), future:get_error())
  local result = future:get_result()
  t.assert_eq("Applied", result.kind, vim.inspect(result))
  return result
end

---@return era.view.ResultTree
local function fixture()
  local source = Source.new("root", { label = "root" })
  source:insert("root", "dir", { label = "dir" })
  source:insert("dir", "one", { label = "one" })
  source:insert("dir", "two", { label = "two" })
  source:insert("root", "three", { label = "three" })
  local tree = Tree.new({
    name = "native results",
    tree = source,
    present = function(_, data)
      return { label = data.label }
    end,
  })
  tree:insert("root", { nodetype = "container" })
  tree:insert("dir", { nodetype = "container" })
  for _, key in ipairs({ "one", "two", "three" }) do
    tree:insert(key, { nodetype = "leaf", text = key })
  end
  t:defer(function()
    tree:dispose()
  end)
  return tree
end

t:test("ordered List filtering retains Tree ancestors and native selection across imports", function()
  local tree = fixture()
  await(tree:publish({ mode = "tree", rootuuid = "root", only_matched = true, orders = { "two" } }))
  t.assert_eq(2, tree:linecount())
  t.assert_eq("dir", tree:retrieve_uuid(1))
  t.assert_eq("two", tree:retrieve_uuid(2))
  tree:toggle_select("two", true, false)
  t.wait_until(function()
    return tree.state:snapshot():flags(tree._data:source():id("two")).marked
  end, 5000)
  await(tree:publish({ mode = "list", rootuuid = "root", orders = { "three", "two" } }))
  t.assert_eq("three", tree:retrieve_uuid(1))
  t.assert_eq("two", tree:retrieve_uuid(2))
  t.assert_true(tree:isselected("two"))
  tree.source:update("two", { label = "updated" })
  await(tree:publish({ mode = "tree", rootuuid = "root", orders = { "two" } }))
  tree:collapse("dir", "collapse", false)
  t.wait_until(function()
    return not tree.state:snapshot():flags(tree._data:source():id("dir")).expanded
  end, 5000)
  await(tree:publish({ mode = "tree", rootuuid = "root" }))
  t.assert_true(tree:isselected("two"), "collapsed selection stays native")
  t.assert_eq("updated", tree:data("two").label)
  t.assert_eq(0, #errors, vim.inspect(errors))
end)

t:test("a native surface keeps old metadata until publication and survives reopening", function()
  local tree = fixture()
  local bufnr = vim.api.nvim_create_buf(false, true)
  local winnr = vim.api.nvim_open_win(bufnr, false, { relative = "editor", row = 0, col = 0, width = 40, height = 10 })
  t:defer(function()
    if vim.api.nvim_win_is_valid(winnr) then
      vim.api.nvim_win_close(winnr, true)
    end
  end)
  tree:mount(winnr, bufnr, function() end)
  await(tree:publish({ mode = "tree", rootuuid = "root" }))
  t.assert_eq("one", tree:data("one").label)
  local identity = tree.state
  tree.source:update("one", { label = "new" })
  local pending = tree:publish({ mode = "tree", rootuuid = "root" })
  t.assert_eq("one", tree:data("one").label)
  await(pending)
  t.assert_eq("new", tree:data("one").label)
  tree:unmount()
  t.assert_false(vim.api.nvim_buf_is_valid(bufnr))
  local next_bufnr = vim.api.nvim_create_buf(false, true)
  winnr = vim.api.nvim_open_win(next_bufnr, false, { relative = "editor", row = 0, col = 0, width = 40, height = 10 })
  tree:mount(winnr, next_bufnr, function() end)
  t.wait_until(function()
    return tree.view and tree.view:frame() ~= nil
  end, 5000)
  t.assert_true(tree.state == identity)
  t.assert_eq("new", tree:data("one").label)
  t.assert_eq(0, #errors, vim.inspect(errors))
end)

t:test("an idle result retains native notifications without another Lua Future", function()
  local tree = fixture()
  local bufnr = vim.api.nvim_create_buf(false, true)
  local winnr = vim.api.nvim_open_win(bufnr, false, { relative = "editor", row = 0, col = 0, width = 40, height = 10 })
  t:defer(function()
    if vim.api.nvim_win_is_valid(winnr) then
      vim.api.nvim_win_close(winnr, true)
    end
  end)
  tree:mount(winnr, bufnr, function() end)
  await(tree:publish({ mode = "tree", rootuuid = "root" }))
  vim.wait(30)
  local ticket = tree.state._native:dispatch({
    kind = "set_expanded",
    nodes = { tree._data:source():id("dir") },
    value = false,
    recursive = false,
  })
  t.wait_until(function()
    return ticket:poll()
  end, 5000)
  t.wait_until(function()
    return tree:linecount() == 2
  end, 5000, "native state change did not reach the idle view")
end)

t:test("queued result refreshes coalesce without mixing their membership and source", function()
  local tree = fixture()
  local first = tree:publish({ mode = "list", orders = { "one" } })
  local second = tree:publish({ mode = "list", orders = { "three" } })
  t.assert_eq("Superseded", first:get_result().kind)
  await(second)
  t.assert_eq(1, tree:linecount())
  t.assert_eq("three", tree:retrieve_uuid(1))
  t.assert_eq(0, #errors, vim.inspect(errors))
end)

t:test("a producer change during preparation supersedes the partial snapshot", function()
  local tree = fixture()
  await(tree:publish({ mode = "list", rootuuid = "root", orders = { "one" } }))
  for index = 1, 600 do
    local key = "queued" .. index
    tree.source:insert("root", key, { label = key })
    tree:insert(key, { nodetype = "leaf" })
  end
  local latest, queued
  local present = tree._present
  t:patch_table(tree, "_present", function(key, data, entry)
    if key == "queued1" and not queued then
      queued = true
      vim.schedule(function()
        tree.source:update("one", { label = "latest" })
        tree:invalidate()
        latest = tree:publish({ mode = "list", rootuuid = "root", orders = { "one" } })
        t.assert_eq("one", tree:data("one").label, "the displayed frame retains old metadata")
      end)
    end
    return present(key, data, entry)
  end)
  local first = tree:publish({ mode = "list", rootuuid = "root", orders = { "two" } })
  t.wait_until(function()
    return latest ~= nil and latest:is_done()
  end, 5000)
  t.assert_eq("Superseded", first:get_result().kind)
  await(latest)
  t.assert_eq("one", tree:retrieve_uuid(1))
  t.assert_eq("latest", tree:data("one").label)
  t.assert_eq(0, #errors, vim.inspect(errors))
end)

t:test("stable topology publishes sparse patches and skips unchanged native records", function()
  local tree = fixture()
  await(tree:publish({ mode = "tree", rootuuid = "root" }))
  local before = tree:frame()
  local id = before:source():id("one")
  local calls, batch = 0, tree._data.batch
  t:patch_table(tree._data, "batch", function(self, operations, revision)
    calls = calls + 1
    t.assert_eq(1, #operations)
    t.assert_eq("one", operations[1].node)
    return batch(self, operations, revision)
  end)
  local restore_import = t:patch_table(tree._data, "begin_import", function()
    error("unchanged topology must not upload the complete result set")
  end)
  tree.source:update("one", { label = "renamed" })
  tree:invalidate()
  await(tree:publish({ mode = "tree", rootuuid = "root" }))
  t.assert_eq(1, calls)
  t.assert_eq(id, tree:frame():source():id("one"))
  t.assert_eq("renamed", tree:frame():node(id).label)
  t.assert_eq("one", before:node(id).label, "retained frames keep their payload")
  tree.source:update("one", { label = "renamed", metadata = "new" })
  tree:invalidate()
  await(tree:publish({ mode = "tree", rootuuid = "root" }))
  t.assert_eq(1, calls, "equal records require no native write")
  t.assert_eq("new", tree:data("one").metadata)
  restore_import()
  tree.source:move("one", "root")
  tree:invalidate()
  await(tree:publish({ mode = "tree", rootuuid = "root" }))
  t.assert_eq(id, tree:frame():source():id("one"), "structural imports still preserve identity")
  t.assert_nil(tree:retrieve_parent("one"), "the moved item is now a displayed root")
end)

t:test("an independent preview's commit does not delay an unchanged main publication", function()
  local tree = fixture()
  await(tree:publish({ mode = "tree", rootuuid = "root" }))
  local future = tree:preview_state("dir", false)
  t.wait_until(function()
    return future:is_done()
  end, 5000)
  t.assert_false(future:is_failed(), future:get_error())
  local preview = future:get_result()
  local collapsed = preview:set_expanded({ tree._data:source():id("dir") }, false, false)
  t.wait_until(function()
    return collapsed:is_done()
  end, 5000)
  await(tree:publish({ mode = "tree", rootuuid = "root" }))
  t.assert_eq(4, tree:linecount())
end)

for _, phase in ipairs({ "create", "display" }) do
  t:test("disposal rejects a late " .. phase .. " reply without restoring native resources", function()
    local tree = fixture()
    if phase == "display" then
      await(tree:publish({ mode = "tree", rootuuid = "root" }))
    end
    local deferred, resolve = stl.c.Future.new_with_resolver()
    local reply
    local target = phase == "create" and tree._data or tree.state
    local method = phase == "create" and "create_state" or "dispatch"
    local original = target[method]
    t:patch_table(target, method, function(self, ...)
      return original(self, ...):then_(function(value)
        reply = value
        return deferred
      end)
    end)
    local publication = tree:publish({ mode = "list", rootuuid = "root", orders = { "one" } })
    t.wait_until(function()
      return reply ~= nil
    end, 5000)
    tree:dispose()
    resolve(reply)
    t.wait_until(function()
      return not tree._busy
    end, 5000)
    t.assert_eq("Rejected", publication:get_result().kind)
    t.assert_nil(tree.state)
    t.assert_nil(tree._data)
    t.assert_nil(tree._frame)
    t.assert_nil(tree._configured)
    t.assert_nil(tree._waiting)
    t.assert_nil(tree._active_request)
  end)
end

t:test("bulk deselection and the next action share one accepted native selection", function()
  local tree = fixture()
  for index = 1, 1000 do
    local key = "bulk" .. index
    tree.source:insert("dir", key, { label = key })
    tree:insert(key, { nodetype = "leaf" })
  end
  await(tree:publish({ mode = "tree", rootuuid = "root" }))
  tree:toggle_select("dir", true, true)
  await(tree:ready())
  for index = 1, 1000 do
    tree:set_selected("bulk" .. index, false)
  end
  local invoked = false
  t.assert_true(tree:after_selection(function()
    invoked = true
    t.assert_false(tree:isselected("bulk1000"))
  end))
  await(tree:ready())
  t.assert_true(invoked)
  t.assert_true(tree:isselected("dir"), "self-only clear keeps the branch's own mark")
  t.assert_eq(0, #errors, vim.inspect(errors))
end)

t:test("bulk selection reads preserve visible order without per-row Lua queries", function()
  local tree = fixture()
  for index = 1, 2000 do
    local key = "extra" .. index
    tree.source:insert("root", key, { label = key })
    tree:insert(key, { nodetype = "leaf" })
  end
  await(tree:publish({ mode = "list", rootuuid = "root", orders = { "two", "three", "one" } }))
  tree:toggle_select("one", true, false)
  tree:toggle_select("two", true, false)
  await(tree:ready())
  t:patch_table(tree, "retrieve_uuid", function()
    error("bulk actions must not resolve every buffer row")
  end)
  t:patch_table(tree, "isselected", function()
    error("bulk actions must not query every producer entry")
  end)
  t.assert_true(tree:has_selected())
  t.assert_true(vim.deep_equal({ "two", "one" }, tree:selected_keys(true)), "visible order")
  t.assert_true(vim.deep_equal({ 1, 3 }, tree:collect_selected_rows()), "visible row numbers")
  t.assert_true(vim.deep_equal({ one = true, two = true }, tree:collect_selected()), "all selected identities")
  await(tree:publish({ mode = "list", rootuuid = "root", orders = { "three" } }))
  t.assert_false(tree:has_selected(), "filtered selection does not become an open target")
  t.assert_true(vim.deep_equal({ one = true, two = true }, tree:collect_selected()), "filtered marks survive")
end)

for _, module in ipairs({
  "era.m.picker.composer.tree",
  "era.m.picker.composer.filetree",
  "era.m.searcher.composer.filetree",
}) do
  t:test(module .. " resolves a published parent identity for collapse", function()
    local tree = fixture()
    await(tree:publish({ mode = "tree", rootuuid = "root" }))
    local composer = setmetatable({ _treeview = tree }, { __index = require(module) })
    local row, key = composer:__retrieve_lnum_parent__("two")
    t.assert_eq(1, row)
    t.assert_eq("dir", key)
    t.assert_nil(composer:__retrieve_lnum_parent__(nil))
    t.assert_nil(composer:__retrieve_lnum_parent__("absent"))
    tree:collapse(key, "collapse", true)
    await(tree:ready())
    t.assert_nil(tree:retrieve_lnum("two"))
    t.assert_true(tree:retrieve("dir").collapsed)
  end)
  t:test(module .. " navigates from a List location to its displayed file", function()
    local tree = fixture()
    tree:insert("one", {
      nodetype = "leaf",
      locations = { { nodetype = "location", leafuuid = "one", locationuuid = "one:1", lnum = 1 } },
    })
    await(tree:publish({ mode = "list", rootuuid = "root", orders = { "one" } }))
    local composer = setmetatable({ _treeview = tree }, { __index = require(module) })
    local row, key = composer:__retrieve_lnum_parent__("one:1")
    t.assert_eq(1, row)
    t.assert_eq("one", key)
  end)
end

t:run()
