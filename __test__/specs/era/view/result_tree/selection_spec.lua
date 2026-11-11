local t = require("__test__.support.harness").new()
local bootstrap = require("__test__.support.bootstrap")
bootstrap.with_native(t)
local reports = bootstrap.with_reporter(t)
local picker = require("__test__.support.picker")
local support = require("__test__.support.treeview")

t:test("bulk deselection and the next action share one accepted native selection", function()
  local tree = picker.branch_tree(t)
  for index = 1, 1000 do
    local key = "bulk" .. index
    tree.source:insert("dir", key, { label = key })
    tree:insert(key, { nodetype = "leaf" })
  end
  support.applied(tree:publish({ mode = "tree", rootuuid = "root" }))
  tree:toggle_select("dir", true, true)
  support.applied(tree:ready())
  for index = 1, 1000 do
    tree:set_selected("bulk" .. index, false)
  end
  local invoked = false
  t.assert_true(tree:after_selection(function()
    invoked = true
    t.assert_false(tree:isselected("bulk1000"))
  end))
  support.applied(tree:ready())
  t.assert_true(invoked)
  t.assert_true(tree:isselected("dir"), "self-only clear keeps the branch's own mark")
  t.assert_same({}, reports.error)
end)

t:test("bulk selection reads preserve visible order without per-row Lua queries", function()
  local tree = picker.branch_tree(t)
  for index = 1, 2000 do
    local key = "extra" .. index
    tree.source:insert("root", key, { label = key })
    tree:insert(key, { nodetype = "leaf" })
  end
  support.applied(tree:publish({ mode = "list", rootuuid = "root", orders = { "two", "three", "one" } }))
  tree:toggle_select("one", true, false)
  tree:toggle_select("two", true, false)
  support.applied(tree:ready())
  t:patch_table(tree, "retrieve_uuid", function()
    error("bulk actions must not resolve every buffer row")
  end)
  t:patch_table(tree, "isselected", function()
    error("bulk actions must not query every producer entry")
  end)
  t.assert_true(tree:has_selected())
  t.assert_same({ "two", "one" }, tree:selected_keys(true), "visible order")
  t.assert_same({ 1, 3 }, tree:collect_selected_rows(), "visible row numbers")
  t.assert_same({ one = true, two = true }, tree:collect_selected(), "all selected identities")
  support.applied(tree:publish({ mode = "list", rootuuid = "root", orders = { "three" } }))
  t.assert_false(tree:has_selected(), "filtered selection does not become an open target")
  t.assert_same({ one = true, two = true }, tree:collect_selected(), "filtered marks survive")
end)

t:test("Visual selection skips marked queries for an empty captured frame", function()
  local tree = picker.branch_tree(t)
  tree:insert("one", {
    nodetype = "leaf",
    locations = { { nodetype = "location", leafuuid = "one", locationuuid = "one:1", lnum = 1 } },
  })
  support.applied(tree:publish({ mode = "list", rootuuid = "root", orders = { "one", "two", "three" } }))
  local captured = tree:frame()
  t.assert_true(captured:header().summary.is_empty)
  tree:set_selected("one", true)
  tree:set_selected("two", true)
  support.applied(tree:ready())
  t.assert_false(tree:frame():header().summary.is_empty)
  local proxy = setmetatable({}, {
    __index = function(_, name)
      if name == "all_marked" or name == "flags" or name == "marked_nodes" then
        error("an empty captured selection must not query marked identities")
      end
      return function(_, ...)
        return captured[name](captured, ...)
      end
    end,
  })
  local submitted, dispatch = nil, tree.state.dispatch
  tree.state.dispatch = function(_, command, context)
    t.assert_eq(proxy, context.frame)
    submitted = command
    return stl.c.Future.resolve({ kind = "Applied" })
  end
  tree.view = {
    detach = function() end,
    frame = function()
      return tree.state:snapshot()
    end,
    is_suspended = function()
      return false
    end,
    range_action = function(_, callback)
      return callback(proxy, 1, 3, true)
    end,
  }
  tree:toggle_selection()
  tree.view = nil
  tree.state.dispatch = dispatch
  t.assert_eq("select_node", submitted.kind)
  t.assert_false(submitted.recursive)
  t.assert_same({ "one", "two" }, captured:node_keys(submitted.nodes))
end)

t:test("Visual selection reads only its range and preserves location and outside marks", function()
  local tree = picker.branch_tree(t)
  tree:insert("one", {
    nodetype = "leaf",
    locations = { { nodetype = "location", leafuuid = "one", locationuuid = "one:1", lnum = 1 } },
  })
  local orders = { "one", "two", "three" }
  for index = 1, 1100 do
    local key = "outside" .. index
    tree.source:insert("root", key, { label = key })
    tree:insert(key, { nodetype = "leaf" })
    orders[#orders + 1] = key
  end
  support.applied(tree:publish({ mode = "list", rootuuid = "root", orders = orders }))
  tree:set_selected("one", true)
  tree:set_selected("one:1", true)
  for index = 1, 1100 do
    tree:set_selected("outside" .. index, true)
  end
  support.applied(tree:ready())
  local marked_reads = 0
  local view = {
    detach = function() end,
    range_action = function(_, callback)
      local frame = tree:frame()
      local proxy = setmetatable({}, {
        __index = function(_, name)
          if name == "marked_nodes" or name == "flags" then
            error("a range action must batch its marked query")
          end
          return function(_, ...)
            if name == "node_at" then
              local row = ...
              t.assert_true(row >= 1 and row <= 3, "only read the captured range")
            elseif name == "all_marked" then
              local ids = ...
              marked_reads = marked_reads + 1
              t.assert_same({ "one", "two" }, frame:node_keys(ids), "only query eligible range nodes")
            end
            return frame[name](frame, ...)
          end
        end,
      })
      local dispatch = tree.state.dispatch
      tree.state.dispatch = function(self, command, context)
        context.frame = frame
        return dispatch(self, command, context)
      end
      local future = callback(proxy, 1, 3, true)
      tree.state.dispatch = dispatch
      return future
    end,
  }
  for _, selected in ipairs({ true, false }) do
    tree.view = view
    view.frame = function()
      return tree.state:snapshot()
    end
    view.is_suspended = function()
      return false
    end
    tree:toggle_selection()
    tree.view = nil
    support.applied(tree:ready())
    t.assert_eq(selected, tree:isselected("one"))
    t.assert_eq(selected, tree:isselected("two"))
    t.assert_true(tree:isselected("one:1"), "location marks are independent")
    t.assert_true(tree:isselected("outside1100"), "outside marks survive")
  end
  t.assert_eq(2, marked_reads, "one marked query per range action")
end)

t:test("range hiding preserves containers and outside marks while including file locations", function()
  local tree = picker.branch_tree(t)
  tree:insert("one", {
    nodetype = "leaf",
    locations = { { nodetype = "location", leafuuid = "one", locationuuid = "one:1", lnum = 1 } },
  })
  tree:mark_node_invisible("previously-hidden")
  support.applied(tree:publish({ mode = "tree", rootuuid = "root" }))
  local frame = tree:frame()
  tree:mark_rows_invisible(frame, 1, tree:retrieve_lnum("two"), true)
  t.assert_true(tree:isvisible("dir"))
  t.assert_false(tree:isvisible("one"))
  t.assert_false(tree:isvisible("one:1"))
  t.assert_false(tree:isvisible("two"))
  t.assert_true(tree:isvisible("three"))
  t.assert_false(tree:isvisible("previously-hidden"))
  support.applied(tree:publish({ mode = "tree", rootuuid = "root" }))
  t.assert_nil(tree:retrieve_lnum("one"))
  t.assert_nil(tree:retrieve_lnum("one:1"))
  t.assert_nil(tree:retrieve_lnum("two"))
  t.assert_true(tree:retrieve_lnum("three") ~= nil)
end)

t:test("range actions retain subtree and Visual semantics and release a throwing submission", function()
  local tree = picker.branch_tree(t)
  local bufnr = t:buffer()
  local winnr = t:window(bufnr, { relative = "editor", row = 0, col = 0, width = 40, height = 10 }, true)
  t:defer(function()
    vim.cmd.normal({ args = { vim.keycode("<Esc>") }, bang = true })
  end)
  tree:mount(winnr, bufnr, function() end)
  support.applied(tree:publish({ mode = "tree", rootuuid = "root" }))
  vim.api.nvim_win_set_cursor(winnr, { 1, 0 })
  local captured
  local future = tree:range_action(function(frame, first, last, visual)
    captured = { frame = frame, first = first, last = last, visual = visual }
  end)
  t.assert_eq("NoChange", future:get_result().kind)
  t.assert_eq(1, captured.first)
  t.assert_eq(3, captured.last)
  t.assert_false(captured.visual)
  t.assert_true(captured.frame == tree.view:frame())
  vim.cmd.normal({ args = { "Vj" }, bang = true })
  tree:range_action(function(_, first, last, visual)
    t.assert_eq(1, first)
    t.assert_eq(2, last)
    t.assert_true(visual)
  end)
  t.assert_eq("n", vim.fn.mode())
  -- The view's own listener sets the minimum and polls at once, even before range_action returns when the command
  -- completes at once; a publication that poll completes clears it, so it is read as the poll starts.
  local minimum_commit
  local poll = tree.view._poll
  t:patch_table(tree.view, "_poll", function(view, ...)
    minimum_commit = minimum_commit or view._minimum_commit
    return poll(view, ...)
  end)
  local submitted
  local dispatched = tree:range_action(function(frame)
    submitted = tree.state:dispatch({
      kind = "select_node",
      nodes = { frame:source():id("one") },
      recursive = false,
    }, { frame = frame })
    return submitted
  end)
  t.assert_true(dispatched == submitted, "native command receipts retain their Future")
  local receipt = support.applied(dispatched)
  t.assert_eq(receipt.revisions.commit, minimum_commit)
  local old_errors = #reports.error
  local failed = tree:range_action(function()
    error("range callback failed", 0)
  end)
  t.assert_true(failed:is_failed())
  t.assert_eq("range callback failed", failed:get_error())
  t.assert_nil(tree.view._submission)
  t.assert_eq(old_errors + 1, #reports.error)
  table.remove(reports.error)
  for _, flag in ipairs({ "_desynced", "_publishing" }) do
    tree.view[flag] = true
    local rejected = tree:range_action(function()
      error("stale callbacks must not run")
    end)
    t.assert_eq("Stale", rejected:get_result().error.code)
    tree.view[flag] = false
  end
end)

t:run()
