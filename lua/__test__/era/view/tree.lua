---@diagnostic disable: undefined-global
--- Run with: nvim -l lua/__test__/era/view/tree.lua

local harness = require("__test__.harness")
local bootstrap = require("__test__.bootstrap")
local Tree = require("stl.c.tree")
local tree_cache = require("era.view.tree.cache")
local tree_collapse = require("era.view.tree.collapse")
local tree_lifecycle = require("era.view.tree.lifecycle")
local tree_selection = require("era.view.tree.selection")
local tree_store = require("era.view.tree.store")
local tree_visibility = require("era.view.tree.visibility")

local t = harness.new("era.view.tree")

bootstrap.with_runtime(t, {
  dot = {
    var = {
      nsnr = {
        view_tree = vim.api.nvim_create_namespace("test-era-view-tree"),
      },
    },
  },
  stl = {
    reporter = {
      error = function(report)
        error(report.message or "unexpected reporter error")
      end,
    },
    table = require("stl.table"),
  },
})

local TreeRenderer = assert(loadfile("lua/era/view/tree.lua"))()
local TestView = {
  isselected = tree_selection.isselected,
  collect_selected = tree_selection.collect_selected,
  set_selected = tree_selection.set_selected,
  toggle_select = tree_selection.toggle_select,
  mark_cache_selected_dirty = tree_selection.mark_dirty,
  __refresh_selected_maximum__ = tree_selection.refresh_selected_maximum,
  isvisible = tree_visibility.isvisible,
  mark_node_invisible = tree_visibility.mark_node_invisible,
  mark_cache_invisible_dirty = tree_visibility.mark_cache_invisible_dirty,
  collapse = tree_collapse.collapse,
  mark_cache_listview_dirty = tree_cache.mark_listview_dirty,
  mark_cache_treeview_dirty = tree_cache.mark_treeview_dirty,
  collect_leafs = tree_store.collect_leafs,
  insert = tree_store.insert,
  remove = tree_store.remove,
  remove_all_locations = tree_store.remove_all_locations,
  remove_location = tree_store.remove_location,
  isdisposed = tree_lifecycle.isdisposed,
  __health__ = tree_lifecycle.health,
  render_listview = TreeRenderer.render_listview,
  render_treeview = TreeRenderer.render_treeview,
}
TestView.__index = TestView

---@param expected any[]
---@param actual any[]
---@param message string
local function assert_array(expected, actual, message)
  t.assert_eq(#expected, #actual, message .. " length")
  for index = 1, #expected do
    t.assert_eq(expected[index], actual[index], string.format("%s[%d]", message, index))
  end
end

---@param nodetype "container"|"leaf"
---@param overrides? table
---@return era.view.tree.INodeState
local function new_state(nodetype, overrides)
  local state = {
    nodetype = nodetype,
    collapsed = false,
    tick_invisible = 0,
    tick_matched = 0,
    tick_selected = -1,
    tick_selected_maximum = -1,
  }
  for key, value in pairs(overrides or {}) do
    state[key] = value
  end
  return state
end

---@class __test__.era.view.tree.INodeSpec
---@field public uuid string
---@field public parent? string
---@field public data? table
---@field public state era.view.tree.INodeState

---@param specs __test__.era.view.tree.INodeSpec[]
---@return stl.c.Tree
---@return era.view.tree.IRenderView
---@return table<string, integer>
local function setup(specs)
  local tree = Tree.new("__virtual_root__", { uuid = "__virtual_root__" })
  local calls = { container = 0, leaf = 0, location = 0, list_leaf = 0, list_location = 0 }
  local checked = {} ---@type table<string, true>
  local view = tree_lifecycle.create({
    name = "test",
    tree = tree,
    render_listview_leaf = function(ctx, uuid, data)
      if not checked.list_leaf then
        checked.list_leaf = true
        t.assert_eq(uuid, data.uuid, "renderer node data")
        t.assert_true(ctx.tree:get(ctx.rootdata.uuid) == ctx.rootdata, "renderer root data")
      end
      calls.list_leaf = calls.list_leaf + 1
      return uuid
    end,
    render_listview_location = function(ctx, uuid, data, _, location)
      if not checked.list_location then
        checked.list_location = true
        t.assert_eq(uuid, data.uuid, "renderer node data")
        t.assert_true(ctx.tree:get(ctx.rootdata.uuid) == ctx.rootdata, "renderer root data")
      end
      calls.list_location = calls.list_location + 1
      return location.locationuuid
    end,
    render_treeview_container = function(ctx, uuid, data, _, _, folded_depth)
      if not checked.container then
        checked.container = true
        t.assert_eq(uuid, data.uuid, "renderer node data")
        t.assert_true(ctx.tree:get(ctx.rootdata.uuid) == ctx.rootdata, "renderer root data")
      end
      calls.container = calls.container + 1
      local text = folded_depth > 0 and string.format("%s:%d", uuid, folded_depth) or uuid
      return text
    end,
    render_treeview_leaf = function(ctx, uuid, data)
      if not checked.leaf then
        checked.leaf = true
        t.assert_eq(uuid, data.uuid, "renderer node data")
        t.assert_true(ctx.tree:get(ctx.rootdata.uuid) == ctx.rootdata, "renderer root data")
      end
      calls.leaf = calls.leaf + 1
      return uuid
    end,
    render_treeview_location = function(ctx, uuid, data, _, location)
      if not checked.location then
        checked.location = true
        t.assert_eq(uuid, data.uuid, "renderer node data")
        t.assert_true(ctx.tree:get(ctx.rootdata.uuid) == ctx.rootdata, "renderer root data")
      end
      calls.location = calls.location + 1
      return location.locationuuid
    end,
  }, "era.view.tree")
  setmetatable(view, TestView)

  for _, spec in ipairs(specs) do
    local parent = spec.parent or tree.root ---@type string
    local children = tree:children(parent) ---@type string[]
    local index = #children + 1 ---@type integer
    for i, childuuid in ipairs(children) do
      if spec.uuid < childuuid then
        index = i
        break
      end
    end
    tree:insert(parent, spec.uuid, spec.data or { uuid = spec.uuid }, index)
    view:insert(spec.uuid, spec.state)
  end
  return tree, view, calls
end

---@param view era.view.tree.IRenderView
---@param bufnr integer
---@param rootuuid string|nil
---@param overrides? table
---@return era.view.tree.IRenderResult
local function render(view, bufnr, rootuuid, overrides)
  local params = {
    bufnr = bufnr,
    rootuuid = rootuuid,
    foldempty = false,
    only_expanded = true,
    only_matched = false,
    only_selected = false,
    only_visible = true,
  }
  for key, value in pairs(overrides or {}) do
    params[key] = value
  end
  return view:render_treeview(params)
end

---@param view era.view.tree.IRenderView
---@param bufnr integer
---@param rootuuid string|nil
---@param overrides? table
---@return era.view.tree.IRenderResult
local function render_list(view, bufnr, rootuuid, overrides)
  local params = {
    bufnr = bufnr,
    rootuuid = rootuuid,
    orders = nil,
    only_matched = false,
    only_selected = false,
    only_visible = true,
  }
  for key, value in pairs(overrides or {}) do
    params[key] = value
  end
  return view:render_listview(params)
end

t:test("render: consumes sorted borrowed children", function()
  local tree, view = setup({
    { uuid = "root", state = new_state("container") },
    { uuid = "z", parent = "root", state = new_state("leaf") },
    { uuid = "a", parent = "root", state = new_state("leaf") },
  })
  local bufnr = vim.api.nvim_create_buf(false, true)

  local children = assert(tree:children("root"))
  t.assert_true(children == tree:children("root"), "children are borrowed")
  assert_array({ "a", "z" }, children, "sorted children")
  t.assert_nil(tree:children("missing"), "missing node children")

  render(view, bufnr, "root")
  assert_array({ "root", "├─a", "╰─z" }, vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "rendered lines")
  vim.api.nvim_buf_delete(bufnr, { force = true })
end)

t:test("empty render: list returns maps and tree returns layout", function()
  local _, view = setup({})
  local bufnr = vim.api.nvim_create_buf(false, true)

  local list_result = render_list(view, bufnr, "missing")
  t.assert_eq(0, #list_result.lnum2uuid, "empty list map")
  t.assert_nil(list_result.layout, "empty list has no layout")

  local tree_result = render(view, bufnr, "missing")
  t.assert_eq(0, assert(tree_result.layout):len(), "empty tree layout")
  t.assert_nil(tree_result.lnum2uuid, "empty tree has no map")
  vim.api.nvim_buf_delete(bufnr, { force = true })
end)

t:test("render: projects visible matched selected expanded topology", function()
  local _, view = setup({
    { uuid = "root", state = new_state("container") },
    { uuid = "branch", parent = "root", state = new_state("container") },
    { uuid = "chosen", parent = "branch", state = new_state("leaf") },
    { uuid = "unmatched", parent = "branch", state = new_state("leaf", { tick_matched = -1 }) },
    { uuid = "hidden", parent = "root", state = new_state("leaf", { tick_invisible = 1 }) },
  })
  local bufnr = vim.api.nvim_create_buf(false, true)
  view:set_selected("chosen", true)

  local result = render(view, bufnr, "root", { only_matched = true, only_selected = true })
  assert_array(
    { "root", "╰─branch", "  ╰─chosen" },
    vim.api.nvim_buf_get_lines(bufnr, 0, -1, false),
    "filtered lines"
  )
  t.assert_eq(3, result.childline[1], "expanded root range")

  view.statemap.branch.collapsed = true
  result = render(view, bufnr, "root", { only_matched = true, only_selected = true })
  assert_array({ "root", "╰─branch" }, vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "collapsed lines")
  t.assert_eq(2, result.childline[1], "collapsed root range")
  t.assert_nil(result.childline[2], "collapsed branch has no visible descendant")
  vim.api.nvim_buf_delete(bufnr, { force = true })
end)

t:test("selected maximum: failed refresh remains dirty for recovery", function()
  local tree, view = setup({
    { uuid = "root", state = new_state("container") },
  })
  tree:insert("root", "late", {})
  view:set_selected("root", true)
  local bufnr = vim.api.nvim_create_buf(false, true)

  local ok = pcall(render, view, bufnr, "root", { only_selected = true })
  t.assert_false(ok, "missing state should fail refresh")

  view:insert("late", new_state("leaf"))
  local result = render(view, bufnr, "root", { only_selected = true })
  t.assert_eq("root", assert(result.layout):id(1), "retry recomputes selected root")
  vim.api.nvim_buf_delete(bufnr, { force = true })
end)

t:test("selected maximum: state rebuild and removal invalidate aggregate", function()
  t:patch_table(table, "clear", function(target)
    for key in pairs(target) do
      target[key] = nil
    end
  end)

  local tree, view = setup({
    { uuid = "root", state = new_state("container") },
    { uuid = "branch", parent = "root", state = new_state("container") },
    { uuid = "chosen", parent = "branch", state = new_state("leaf") },
  })
  local bufnr = vim.api.nvim_create_buf(false, true)
  view:set_selected("chosen", true)
  render(view, bufnr, "root", { only_selected = true })

  tree_lifecycle.clear(view)
  view:insert("root", new_state("container"))
  view:insert("branch", new_state("container"))
  view:insert("chosen", new_state("leaf", { tick_selected = view._tick_selected }))

  local rebuilt = render(view, bufnr, "root", { only_selected = true })
  assert_array(
    { "root", "╰─branch", "  ╰─chosen" },
    vim.api.nvim_buf_get_lines(bufnr, 0, -1, false),
    "rebuilt selected lines"
  )
  t.assert_eq(view._tick_selected, view.statemap.chosen.tick_selected_maximum, "leaf selected maximum")
  t.assert_eq(view._tick_selected, view.statemap.root.tick_selected_maximum, "root selected maximum")
  t.assert_eq(3, assert(rebuilt.layout):len(), "rebuilt selected layout")

  view:remove("chosen")
  tree:remove("chosen")
  local removed = render(view, bufnr, "root", { only_selected = true })
  t.assert_eq(0, assert(removed.layout):len(), "removed selected layout")
  vim.api.nvim_buf_delete(bufnr, { force = true })
end)

t:test("list render: preserves subtree filters and explicit orders", function()
  local location1 = { nodetype = "location", leafuuid = "chosen", locationuuid = "chosen:1", tick_invisible = 0 }
  local location2 = { nodetype = "location", leafuuid = "chosen", locationuuid = "chosen:2", tick_invisible = 0 }
  local _, view = setup({
    { uuid = "root", state = new_state("container") },
    { uuid = "branch", parent = "root", state = new_state("container") },
    {
      uuid = "chosen",
      parent = "branch",
      state = new_state("leaf", { locations = { location1, location2 } }),
    },
    { uuid = "unmatched", parent = "branch", state = new_state("leaf", { tick_matched = -1 }) },
    { uuid = "hidden", parent = "root", state = new_state("leaf", { tick_invisible = 1 }) },
  })
  local bufnr = vim.api.nvim_create_buf(false, true)
  view:set_selected("chosen", true)

  local result = render_list(view, bufnr, "root", { only_matched = true, only_selected = true })
  assert_array(
    { "chosen", "├─chosen:1", "╰─chosen:2" },
    vim.api.nvim_buf_get_lines(bufnr, 0, -1, false),
    "filtered list"
  )
  assert_array({ 3, 3, 3 }, result.childline, "filtered list childline")

  result = render_list(view, bufnr, "root", {
    orders = { "unmatched", "chosen", "missing", "branch" },
    only_visible = false,
  })
  assert_array(
    { "unmatched", "chosen", "├─chosen:1", "╰─chosen:2" },
    vim.api.nvim_buf_get_lines(bufnr, 0, -1, false),
    "ordered list"
  )
  assert_array({ "unmatched", "chosen", "chosen:1", "chosen:2" }, result.lnum2uuid, "ordered identities")
  vim.api.nvim_buf_delete(bufnr, { force = true })
end)

t:test("render: folded chain keeps every identity on the representative row", function()
  local _, view, calls = setup({
    { uuid = "root", state = new_state("container") },
    { uuid = "a", parent = "root", state = new_state("container") },
    { uuid = "b", parent = "a", state = new_state("container") },
    { uuid = "leaf", parent = "b", state = new_state("leaf") },
  })
  local bufnr = vim.api.nvim_create_buf(false, true)

  local result = render(view, bufnr, "root", { foldempty = true })
  assert_array({ "b:2", "╰─leaf" }, vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "folded lines")
  local layout = assert(result.layout)
  t.assert_eq("b", layout:id(1), "exposed layout representative")
  t.assert_eq(1, layout:lnum("root"), "exposed layout folded lookup")
  t.assert_eq(2, result.childline[1], "folded subtree range")
  t.assert_eq(1, calls.container, "only representative container renders")
  vim.api.nvim_buf_delete(bufnr, { force = true })
end)

t:test("render: preserves location and sibling-leaf childline semantics", function()
  local location1 = { nodetype = "location", leafuuid = "a", locationuuid = "a:1", tick_invisible = 0 }
  local location2 = { nodetype = "location", leafuuid = "a", locationuuid = "a:2", tick_invisible = 0 }
  local _, view = setup({
    { uuid = "root", state = new_state("container") },
    { uuid = "a", parent = "root", state = new_state("leaf", { locations = { location1, location2 } }) },
    { uuid = "b", parent = "root", state = new_state("leaf") },
    { uuid = "c", parent = "root", state = new_state("leaf") },
  })
  local bufnr = vim.api.nvim_create_buf(false, true)

  local result = render(view, bufnr, "root")
  assert_array(
    { "root", "├─a", "│ ├─a:1", "│ ╰─a:2", "├─b", "╰─c" },
    vim.api.nvim_buf_get_lines(bufnr, 0, -1, false),
    "location lines"
  )
  assert_array({ 6, 4, 4, 4, 6, 6 }, result.childline, "childline")
  vim.api.nvim_buf_delete(bufnr, { force = true })
end)

t:test("render: caches nodes but not location rows", function()
  local location = { nodetype = "location", leafuuid = "leaf", locationuuid = "leaf:1", tick_invisible = 0 }
  local _, view, calls = setup({
    { uuid = "root", state = new_state("container") },
    { uuid = "leaf", parent = "root", state = new_state("leaf", { locations = { location } }) },
  })
  local bufnr = vim.api.nvim_create_buf(false, true)

  render(view, bufnr, "root")
  render(view, bufnr, "root")
  t.assert_eq(1, calls.container, "container cache")
  t.assert_eq(1, calls.leaf, "leaf cache")
  t.assert_eq(2, calls.location, "location rerender")

  view:mark_cache_treeview_dirty()
  render(view, bufnr, "root")
  t.assert_eq(2, calls.container, "dirty container cache")
  t.assert_eq(2, calls.leaf, "dirty leaf cache")
  t.assert_eq(3, calls.location, "dirty location rerender")

  render_list(view, bufnr, "root")
  render_list(view, bufnr, "root")
  t.assert_eq(1, calls.list_leaf, "list leaf cache")
  t.assert_eq(2, calls.list_location, "list location rerender")

  view:mark_cache_listview_dirty()
  render_list(view, bufnr, "root")
  t.assert_eq(2, calls.list_leaf, "dirty list leaf cache")
  t.assert_eq(3, calls.list_location, "dirty list location rerender")
  vim.api.nvim_buf_delete(bufnr, { force = true })
end)

t:test("render: folds depth 10000 without Lua recursion", function()
  local specs = {} ---@type __test__.era.view.tree.INodeSpec[]
  for index = 1, 10000 do
    specs[index] = {
      uuid = tostring(index),
      parent = index > 1 and tostring(index - 1) or nil,
      state = new_state("container"),
    }
  end
  specs[#specs + 1] = { uuid = "leaf", parent = "10000", state = new_state("leaf") }
  local _, view = setup(specs)
  local bufnr = vim.api.nvim_create_buf(false, true)
  view:set_selected("leaf", true)

  local result = render(view, bufnr, "1", { foldempty = true, only_selected = true })
  local layout = assert(result.layout)
  t.assert_eq(2, layout:len(), "deep folded row count")
  t.assert_eq(1, layout:lnum("1"), "deep first identity")
  t.assert_eq(1, layout:lnum("10000"), "deep representative identity")

  local list_result = render_list(view, bufnr, "1", { only_selected = true })
  t.assert_eq("leaf", list_result.lnum2uuid[1], "deep list leaf")
  vim.api.nvim_buf_delete(bufnr, { force = true })
end)

t:test("render: 5000-node time and heap regression ceiling", function()
  local specs = { { uuid = "root", state = new_state("container") } } ---@type __test__.era.view.tree.INodeSpec[]
  for index = 1, 5000 do
    specs[#specs + 1] = { uuid = string.format("leaf-%05d", index), parent = "root", state = new_state("leaf") }
  end
  local _, view = setup(specs)
  local bufnr = vim.api.nvim_create_buf(false, true)

  collectgarbage("collect")
  collectgarbage("stop")
  local heap_before = collectgarbage("count")
  local started_at = vim.uv.hrtime()
  local ok, result = pcall(render, view, bufnr, "root")
  local elapsed_ms = (vim.uv.hrtime() - started_at) / 1e6
  local heap_kib = collectgarbage("count") - heap_before
  collectgarbage("restart")
  if not ok then
    error(result, 0)
  end

  print(string.format("BENCH era-tree-render 5000 time=%.3fms heap=%.1fKiB", elapsed_ms, heap_kib))
  t.assert_eq(5001, assert(result.layout):len(), "benchmark row count")
  t.assert_true(elapsed_ms < 100, "5000-node render should stay below the regression ceiling")
  t.assert_true(heap_kib < 32768, "5000-node render should stay below the heap regression ceiling")

  collectgarbage("collect")
  collectgarbage("stop")
  heap_before = collectgarbage("count")
  started_at = vim.uv.hrtime()
  ok, result = pcall(render_list, view, bufnr, "root")
  elapsed_ms = (vim.uv.hrtime() - started_at) / 1e6
  heap_kib = collectgarbage("count") - heap_before
  collectgarbage("restart")
  if not ok then
    error(result, 0)
  end

  print(string.format("BENCH era-list-render 5000 time=%.3fms heap=%.1fKiB", elapsed_ms, heap_kib))
  t.assert_eq(5000, #result.lnum2uuid, "list benchmark row count")
  t.assert_true(elapsed_ms < 100, "5000-node list render should stay below the regression ceiling")
  t.assert_true(heap_kib < 32768, "5000-node list render should stay below the heap regression ceiling")
  vim.api.nvim_buf_delete(bufnr, { force = true })
end)

t:run()
