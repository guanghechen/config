---@diagnostic disable: undefined-global
--- Run with: nvim -l lua/__test__/stl/view/treeview.lua

local harness = require("__test__.harness")
local treeview = require("stl.view.treeview")

local t = harness.new("stl.view.treeview")

local CHILDREN = {
  a = { "c", "d" },
  b = { "e" },
  c = {},
  d = {},
  e = {},
} ---@type table<string, string[]>

---@param children_by_id table<string, string[]>
---@param roots? string[]
---@param collapsed? table<string, true>
---@return stl.view.TreeLayout
local function layout(children_by_id, roots, collapsed)
  return treeview.layout({
    roots = roots or { "a", "b" },
    children = function(id)
      return children_by_id[id] or {}
    end,
    collapsed = collapsed,
  })
end

t:test("layout: builds an ordered forest and O(1) navigation", function()
  local result = layout(CHILDREN)

  t.assert_eq(5, result:len(), "layout length")
  t.assert_eq(4, result:last_root_lnum(), "last root")
  t.assert_eq("a", result:id(1), "first root")
  t.assert_eq("c", result:id(2), "first child")
  t.assert_eq("d", result:id(3), "second child")
  t.assert_eq("b", result:id(4), "second root")
  t.assert_eq("e", result:id(5), "second root child")

  t.assert_eq(1, result:lnum("a"), "id lookup")
  t.assert_eq(0, result:depth(1), "root depth")
  t.assert_eq(1, result:depth(2), "child depth")

  t.assert_nil(result:parent_lnum(1), "root parent")
  t.assert_eq(1, result:parent_lnum(2), "child parent")
  t.assert_eq(2, result:first_child_lnum(1), "first child")
  t.assert_eq(3, result:last_child_lnum(1), "last child")
  t.assert_nil(result:last_child_lnum(2), "leaf has no child")
  t.assert_eq(3, result:last_descendant_lnum(1), "last descendant")
  t.assert_eq(3, result:next_sibling_lnum(2), "next sibling")
  t.assert_eq(4, result:next_sibling_lnum(1), "next root")
  t.assert_false(result:is_last(2), "first child is not last")
  t.assert_true(result:is_last(3), "second child is last")
  t.assert_nil(result:first_child_lnum(0), "invalid line has no child")
end)

t:test("layout: empty forest has no last root", function()
  local result = layout({}, {})
  t.assert_nil(result:last_root_lnum(), "empty forest last root")
end)

t:test("layout: traverses object-backed topology without copying children", function()
  local leaf = { id = "leaf", children = {} }
  local branch = { id = "branch", children = { leaf } }
  local id_calls = {} ---@type table<string, integer>

  local result = treeview.layout({
    roots = { branch },
    id = function(node)
      id_calls[node.id] = (id_calls[node.id] or 0) + 1
      return node.id
    end,
    children = function(node)
      return node.children
    end,
    can_fold = function(parent, child)
      return parent == branch and child == leaf
    end,
  })

  t.assert_eq(1, result:len(), "object-backed folded length")
  t.assert_eq("leaf", result:id(1), "object-backed representative")
  t.assert_eq(1, result:lnum("branch"), "object-backed parent lookup")
  t.assert_eq(1, id_calls.branch, "parent ID resolution count")
  t.assert_eq(1, id_calls.leaf, "child ID resolution count")
end)

t:test("layout: collapsed nodes remain visible and skip child lookup", function()
  local child_calls = {} ---@type table<string, integer>
  local result = treeview.layout({
    roots = { "a", "b" },
    collapsed = { a = true },
    children = function(id)
      child_calls[id] = (child_calls[id] or 0) + 1
      return CHILDREN[id] or {}
    end,
  })

  t.assert_eq(3, result:len(), "collapsed length")
  t.assert_eq("a", result:id(1), "collapsed root remains")
  t.assert_eq("b", result:id(2), "second root")
  t.assert_eq("e", result:id(3), "expanded child")
  t.assert_nil(result:first_child_lnum(1), "collapsed node has no visible child")
  t.assert_eq(1, result:last_descendant_lnum(1), "collapsed range")
  t.assert_nil(child_calls.a, "collapsed node skips child lookup")
  t.assert_eq(1, child_calls.b, "expanded node child lookup")
end)

t:test("layout: folds single-child chains without losing node identity", function()
  local children_by_id = {
    a = { "b" },
    b = { "c" },
    c = { "d", "e" },
    d = {},
    e = {},
    x = {},
  } ---@type table<string, string[]>

  local result = treeview.layout({
    roots = { "a", "x" },
    children = function(id)
      return children_by_id[id]
    end,
    can_fold = function()
      return true
    end,
  })

  t.assert_eq(4, result:len(), "folded layout length")
  t.assert_eq("c", result:id(1), "deepest folded node represents the row")
  t.assert_eq(1, result:lnum("a"), "first folded ID lookup")
  t.assert_eq(1, result:lnum("b"), "middle folded ID lookup")
  t.assert_eq(1, result:lnum("c"), "representative ID lookup")

  ---@diagnostic disable-next-line: assign-type-mismatch
  local folded_ids = result:folded_ids(1) ---@type string[]
  t.assert_eq(3, #folded_ids, "folded ID count")
  t.assert_eq("a", folded_ids[1], "folded chain start")
  t.assert_eq("b", folded_ids[2], "folded chain middle")
  t.assert_eq("c", folded_ids[3], "folded chain representative")
  t.assert_nil(result:folded_ids(2), "unfolded row has no folded IDs")

  t.assert_eq(0, result:depth(1), "folded row depth")
  t.assert_eq(1, result:depth(2), "folded child depth")
  t.assert_eq(1, result:parent_lnum(2), "folded child parent")
  t.assert_eq(3, result:last_child_lnum(1), "folded last child")
  t.assert_eq(3, result:last_descendant_lnum(1), "folded subtree range")
  t.assert_eq(4, result:next_sibling_lnum(1), "folded root sibling")
end)

t:test("layout: fold predicate controls each eligible edge", function()
  local result = treeview.layout({
    roots = { "a" },
    children = function(id)
      return ({
        a = { "b" },
        b = { "c" },
        c = {},
      })[id]
    end,
    can_fold = function(parent_id)
      return parent_id == "a"
    end,
  })

  t.assert_eq(2, result:len(), "partially folded layout length")
  t.assert_eq("b", result:id(1), "accepted edge is folded")
  t.assert_eq("c", result:id(2), "rejected edge remains a child row")
  t.assert_eq(1, result:parent_lnum(2), "rejected edge preserves navigation")
end)

t:test("layout: folded collapsed node skips child lookup", function()
  local child_calls = {} ---@type table<string, integer>
  local result = treeview.layout({
    roots = { "a" },
    children = function(id)
      child_calls[id] = (child_calls[id] or 0) + 1
      return ({
        a = { "b" },
        b = { "c" },
        c = {},
      })[id]
    end,
    collapsed = { b = true },
    can_fold = function()
      return true
    end,
  })

  t.assert_eq(1, result:len(), "collapsed folded layout length")
  t.assert_eq("b", result:id(1), "collapsed node represents folded row")
  t.assert_eq(1, child_calls.a, "folded parent child lookup")
  t.assert_nil(child_calls.b, "collapsed node skips child lookup")
end)

t:test("layout: rejects cycles and duplicate IDs", function()
  local ok, err = pcall(function()
    layout({ a = { "b" }, b = { "a" } }, { "a" })
  end)

  t.assert_false(ok, "cycle must fail")
  t.assert_true(tostring(err):find("appears more than once", 1, true) ~= nil, "cycle error")
end)

t:test("layout: handles a depth-10000 tree iteratively", function()
  local children_by_id = {} ---@type table<string, string[]>
  for i = 1, 10000 do
    children_by_id[tostring(i)] = i < 10000 and { tostring(i + 1) } or {}
  end

  local result = layout(children_by_id, { "1" })
  t.assert_eq(10000, result:len(), "deep layout length")
  t.assert_eq(9999, result:depth(10000), "deep layout depth")
  t.assert_eq(10000, result:last_descendant_lnum(1), "deep root range")
end)

t:test("layout: 50000-node regression benchmark", function()
  local node_count = 50000 ---@type integer
  local fanout = 8 ---@type integer
  local children_by_id = {} ---@type table<string, string[]>

  for i = 1, node_count do
    children_by_id[tostring(i)] = {}
  end
  for i = 2, node_count do
    local parent = math.floor((i - 2) / fanout) + 1 ---@type integer
    local children = children_by_id[tostring(parent)] ---@type string[]
    children[#children + 1] = tostring(i)
  end

  collectgarbage("collect")
  collectgarbage("stop")
  local heap_before = collectgarbage("count") ---@type number
  local started_at = vim.uv.hrtime() ---@type integer
  local ok, result = pcall(layout, children_by_id, { "1" }) ---@type boolean, stl.view.TreeLayout|string
  local elapsed_ms = (vim.uv.hrtime() - started_at) / 1e6 ---@type number
  local heap_kib = collectgarbage("count") - heap_before ---@type number
  collectgarbage("restart")

  if not ok then
    error(result, 0)
  end
  ---@cast result stl.view.TreeLayout

  print(string.format("BENCH treeview-layout 50000 time=%.3fms heap=%.1fKiB", elapsed_ms, heap_kib))

  t.assert_eq(node_count, result:len(), "benchmark layout length")
  t.assert_true(elapsed_ms < 50, "50000-node layout should stay below the regression ceiling")
  t.assert_true(heap_kib < 16384, "50000-node layout should stay below the heap regression ceiling")
end)

t:run()
