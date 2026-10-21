local t = require("__test__.support.harness").new()
local bootstrap = require("__test__.support.bootstrap")
bootstrap.with_native(t)
local reports = bootstrap.with_reporter(t)
local support = require("__test__.support.treeview")
local Source = require("era.view.result_source")
local Tree = require("era.view.result_tree")

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
  support.applied(tree:publish({ mode = "tree", rootuuid = "root", only_matched = true, orders = { "two" } }))
  t.assert_eq(2, tree:linecount())
  t.assert_eq("dir", tree:retrieve_uuid(1))
  t.assert_eq("two", tree:retrieve_uuid(2))
  tree:toggle_select("two", true, false)
  t.wait_until(function()
    return tree.state:snapshot():flags(tree._data:source():id("two")).marked
  end, 5000)
  support.applied(tree:publish({ mode = "list", rootuuid = "root", orders = { "three", "two" } }))
  t.assert_eq("three", tree:retrieve_uuid(1))
  t.assert_eq("two", tree:retrieve_uuid(2))
  t.assert_true(tree:isselected("two"))
  tree.source:update("two", { label = "updated" })
  support.applied(tree:publish({ mode = "tree", rootuuid = "root", orders = { "two" } }))
  tree:collapse("dir", "collapse", false)
  t.wait_until(function()
    return not tree.state:snapshot():flags(tree._data:source():id("dir")).expanded
  end, 5000)
  support.applied(tree:publish({ mode = "tree", rootuuid = "root" }))
  t.assert_true(tree:isselected("two"), "collapsed selection stays native")
  t.assert_eq("updated", tree:data("two").label)
  t.assert_same({}, reports.error)
end)

t:test("ready waits for every collapse change that is still in flight", function()
  local tree = fixture()
  support.applied(tree:publish({ mode = "tree", rootuuid = "root" }))
  local releases = {} ---@type fun(value: any)[]
  local original = tree.state.dispatch
  t:patch_table(tree.state, "dispatch", function(self, command, context)
    local deferred, release = stl.c.Future.new_with_resolver()
    releases[#releases + 1] = release
    return deferred:then_(function()
      return original(self, command, context)
    end)
  end)
  local id = tree._data:source():id("dir")
  tree:collapse("dir", "collapse", false)
  tree:collapse("dir", "expand", false)
  local ready = tree:ready()
  t.assert_false(
    vim.wait(50, function()
      return ready:is_done()
    end),
    "ready settled before any change applied"
  )
  releases[1]()
  t.wait_until(function()
    return not tree.state:snapshot():flags(id).expanded
  end, 5000)
  t.assert_false(
    vim.wait(50, function()
      return ready:is_done()
    end),
    "ready settled while the second change was in flight"
  )
  releases[2]()
  local frame = support.applied(ready).frame
  t.assert_true(frame:flags(id).expanded, "ready frame includes both changes")
  t.assert_same({}, reports.error)
end)

t:test("input deferred behind a collapse decides on the Frame that shows it", function()
  local tree = fixture()
  support.applied(tree:publish({ mode = "tree", rootuuid = "root" }))
  local id = tree._data:source():id("dir")
  local before = tree:frame()
  local release ---@type fun(value: any)|nil
  local original = tree.state.dispatch
  t:patch_table(tree.state, "dispatch", function(self, command, context)
    local deferred, resolve = stl.c.Future.new_with_resolver()
    release = resolve
    return deferred:then_(function()
      return original(self, command, context)
    end)
  end)
  t.assert_false(
    tree:after_collapse(function()
      error("an idle tree must run input at once")
    end),
    "idle input is not deferred"
  )
  tree:collapse("dir", "collapse", false)
  t.assert_true(tree:collapse_pending(), "a submitted change is pending")
  local expanded ---@type boolean|nil
  t.assert_true(tree:after_collapse(function()
    expanded = tree:frame():flags(id).expanded
  end))
  t.assert_false(
    vim.wait(50, function()
      return expanded ~= nil
    end),
    "deferred input ran before the change applied"
  )
  assert(release)()
  t.wait_until(function()
    return expanded ~= nil
  end, 5000)
  t.assert_false(expanded, "deferred input sees the collapsed directory")
  t.assert_false(tree:collapse_pending(), "a shown change is no longer pending")
  -- A mounted View publishes after the change applies; until then it still presents the old Frame.
  t:patch_table(tree, "frame", function()
    return before
  end)
  t.assert_true(tree:collapse_pending(), "an applied but unpublished change is pending")
  tree:_published(tree.state:snapshot())
  t.assert_false(tree:collapse_pending(), "after publication, later lag is unrelated to the change")
  t.assert_same({}, reports.error)
end)

t:test("ready settles when a publication that leaves the mounted Frame unchanged finishes", function()
  local tree = fixture()
  local bufnr = vim.api.nvim_create_buf(false, true)
  local winnr = vim.api.nvim_open_win(bufnr, false, { relative = "editor", row = 0, col = 0, width = 40, height = 10 })
  t:defer(function()
    if vim.api.nvim_win_is_valid(winnr) then
      vim.api.nvim_win_close(winnr, true)
    end
  end)
  tree:mount(winnr, bufnr, function() end)
  local request = { mode = "tree", rootuuid = "root" }
  support.applied(tree:publish(request))
  support.applied(tree:ready())
  local release ---@type fun(value: any)|nil
  local display = tree._display
  t:patch_table(tree, "_display", function(self, ...)
    local deferred, resolve = stl.c.Future.new_with_resolver()
    release = resolve
    local args = { ... }
    return deferred:then_(function()
      return display(self, unpack(args))
    end)
  end)
  local publication = tree:publish(request)
  t.wait_until(function()
    return release ~= nil
  end, 5000)
  local ready = tree:ready()
  -- Let the idle poll loop stop, so only the drain itself can settle the waiter.
  vim.wait(100)
  t.assert_false(ready:is_done(), "ready waits for the publication")
  assert(release)()
  support.applied(publication)
  t.wait_until(function()
    return ready:is_done()
  end, 2000, "ready must settle once the publication finishes")
  t.assert_eq("Applied", ready:get_result().kind)
end)

t:test("sparse presentation columns preserve defaults across import chunks and later updates", function()
  local source = Source.new("root", { label = "root" })
  local special = { ["1"] = true, ["513"] = true }
  local tree = Tree.new({
    name = "sparse presentation",
    tree = source,
    present = function(key, data)
      return {
        label = data.label,
        icon = special[key] and "*" or nil,
        score = special[key] and 5 or nil,
        fields = special[key] and { value = key } or nil,
      }
    end,
  })
  t:defer(function()
    tree:dispose()
  end)
  for index = 1, 600 do
    local key = tostring(index)
    source:insert("root", key, { label = key })
    tree:insert(key, { nodetype = "leaf" })
  end
  support.applied(tree:publish({ mode = "list", rootuuid = "root", all_rows = true }))
  local before = tree:frame()
  for _, key in ipairs({ "1", "2", "256", "257", "512", "513", "514", "600" }) do
    local node = before:node(before:source():id(key))
    t.assert_eq(special[key] and "*" or nil, node.icon)
    t.assert_eq(special[key] and key or nil, node.fields.value)
  end
  special = { ["2"] = true }
  tree:invalidate()
  support.applied(tree:publish({ mode = "list", rootuuid = "root", all_rows = true }))
  for _, key in ipairs({ "1", "2", "513" }) do
    local frame = tree:frame()
    local node = frame:node(frame:source():id(key))
    t.assert_eq(special[key] and "*" or nil, node.icon)
    t.assert_eq(special[key] and key or nil, node.fields.value)
  end
  t.assert_eq("*", before:node(before:source():id("513")).icon)
end)

t:test("foldempty compacts filtered directory chains and restores their full topology", function()
  local records = {
    { "rust", "root", "container", "rust" },
    { "yoz", "rust", "container", "yoz" },
    { "readme", "rust", "leaf", "README.md" },
    { "src", "yoz", "container", "src" },
    { "manifest", "yoz", "leaf", "Cargo.toml" },
    { "macos", "src", "leaf", "macos.rs" },
    { "linux", "src", "leaf", "linux.rs" },
    { "cargo", "root", "container", ".cargo" },
    { "config", "cargo", "leaf", "config.macos.toml" },
  }
  local source = Source.new("root", { label = "root" })
  for _, record in ipairs(records) do
    source:insert(record[2], record[1], { label = record[4] })
  end
  local tree = Tree.new({
    name = "filtered directory compression",
    tree = source,
    present = function(_, data)
      return { label = data.label }
    end,
  })
  t:defer(function()
    tree:dispose()
  end)
  tree:insert("root", { nodetype = "container" })
  for _, record in ipairs(records) do
    tree:insert(record[1], { nodetype = record[3] })
  end
  local request = {
    mode = "tree",
    rootuuid = "root",
    foldempty = true,
    only_matched = true,
    orders = { "config", "macos" },
  }
  support.applied(tree:publish(request))
  local compact = tree:frame()
  t.assert_eq(4, tree:linecount(), "unmatched siblings must not split the directory chain")
  t.assert_eq("rust/yoz/src", compact:rows(1, 1).labels[1])
  t.assert_eq("src", tree:retrieve_uuid(1), "the deepest directory represents the compact row")
  t.assert_eq("macos", tree:retrieve_uuid(2), "files keep their own row")
  t.assert_eq(2, compact:subtree_end(1), "compressed rows keep their displayed subtree boundary")
  t.assert_eq(4, compact:subtree_end(3))

  request.foldempty = false
  support.applied(tree:publish(request))
  t.assert_eq(6, tree:linecount(), "disabling foldempty restores every matching ancestor")
  request.foldempty = true
  support.applied(tree:publish(request))
  t.assert_eq(4, tree:linecount())
  request.only_matched = false
  support.applied(tree:publish(request))
  t.assert_eq(9, tree:linecount(), "clearing the filter restores the original branching topology")
  t.assert_eq(4, compact:header().row_count, "old frames retain their compressed mapping")
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
  support.applied(tree:publish({ mode = "tree", rootuuid = "root" }))
  t.assert_eq("one", tree:data("one").label)
  local identity = tree.state
  tree.source:update("one", { label = "new" })
  local pending = tree:publish({ mode = "tree", rootuuid = "root" })
  t.assert_eq("one", tree:data("one").label)
  support.applied(pending)
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
  t.assert_same({}, reports.error)
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
  support.applied(tree:publish({ mode = "tree", rootuuid = "root" }))
  -- Let the poll loop go idle; if it is still running, the check below is weaker, not wrong.
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
  support.applied(second)
  t.assert_eq(1, tree:linecount())
  t.assert_eq("three", tree:retrieve_uuid(1))
  t.assert_same({}, reports.error)
end)

t:test("a producer change during preparation supersedes the partial snapshot", function()
  local tree = fixture()
  support.applied(tree:publish({ mode = "list", rootuuid = "root", orders = { "one" } }))
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
  support.applied(latest)
  t.assert_eq("one", tree:retrieve_uuid(1))
  t.assert_eq("latest", tree:data("one").label)
  t.assert_same({}, reports.error)
end)

t:test("stable topology publishes sparse patches and skips unchanged native records", function()
  local tree = fixture()
  support.applied(tree:publish({ mode = "tree", rootuuid = "root" }))
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
  support.applied(tree:publish({ mode = "tree", rootuuid = "root" }))
  t.assert_eq(1, calls)
  t.assert_eq(id, tree:frame():source():id("one"))
  t.assert_eq("renamed", tree:frame():node(id).label)
  t.assert_eq("one", before:node(id).label, "retained frames keep their payload")
  tree.source:update("one", { label = "renamed", metadata = "new" })
  tree:invalidate()
  support.applied(tree:publish({ mode = "tree", rootuuid = "root" }))
  t.assert_eq(1, calls, "equal records require no native write")
  t.assert_eq("new", tree:data("one").metadata)
  restore_import()
  tree.source:move("one", "root")
  tree:invalidate()
  support.applied(tree:publish({ mode = "tree", rootuuid = "root" }))
  t.assert_eq(id, tree:frame():source():id("one"), "structural imports still preserve identity")
  t.assert_nil(tree:retrieve_parent("one"), "the moved item is now a displayed root")
end)

t:test("an independent preview's commit does not delay an unchanged main publication", function()
  local tree = fixture()
  support.applied(tree:publish({ mode = "tree", rootuuid = "root" }))
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
  support.applied(tree:publish({ mode = "tree", rootuuid = "root" }))
  t.assert_eq(4, tree:linecount())
end)

for _, phase in ipairs({ "create", "display" }) do
  t:test("disposal rejects a late " .. phase .. " reply without restoring native resources", function()
    local tree = fixture()
    if phase == "display" then
      support.applied(tree:publish({ mode = "tree", rootuuid = "root" }))
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
  local tree = fixture()
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
  local tree = fixture()
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
  local tree = fixture()
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

for _, module in ipairs({
  "era.m.picker.composer.tree",
  "era.m.picker.composer.filetree",
  "era.m.searcher.composer.filetree",
}) do
  t:test(module .. " resolves a published parent identity for collapse", function()
    local tree = fixture()
    support.applied(tree:publish({ mode = "tree", rootuuid = "root" }))
    local composer = setmetatable({ _treeview = tree }, { __index = require(module) })
    local row, key = composer:__retrieve_lnum_parent__("two")
    t.assert_eq(1, row)
    t.assert_eq("dir", key)
    t.assert_nil(composer:__retrieve_lnum_parent__(nil))
    t.assert_nil(composer:__retrieve_lnum_parent__("absent"))
    tree:collapse(key, "collapse", true)
    support.applied(tree:ready())
    t.assert_nil(tree:retrieve_lnum("two"))
    t.assert_true(tree:retrieve("dir").collapsed)
  end)
  t:test(module .. " navigates from a List location to its displayed file", function()
    local tree = fixture()
    tree:insert("one", {
      nodetype = "leaf",
      locations = { { nodetype = "location", leafuuid = "one", locationuuid = "one:1", lnum = 1 } },
    })
    support.applied(tree:publish({ mode = "list", rootuuid = "root", orders = { "one" } }))
    local composer = setmetatable({ _treeview = tree }, { __index = require(module) })
    local row, key = composer:__retrieve_lnum_parent__("one:1")
    t.assert_eq(1, row)
    t.assert_eq("one", key)
  end)
end

t:test("bulk row reads retain metadata and page identities without exporting node payloads", function()
  local tree = fixture()
  local keys = {}
  for index = 1, 2050 do
    local key = "bulk-" .. index
    keys[index] = key
    tree.source:insert("root", key, { label = key })
    tree:insert(key, { nodetype = "leaf", text = key })
  end
  support.applied(tree:publish({ mode = "list", rootuuid = "root", orders = keys }))
  local frame = tree:frame()
  local pages = 0
  local proxy = setmetatable({}, {
    __index = function(_, name)
      return function(_, ...)
        t.assert_false(name == "node" or name == "rows" or name == "flags", "identity reads must omit " .. name)
        if name == "row_keys" then
          pages = pages + 1
        end
        return frame[name](frame, ...)
      end
    end,
  })
  local iterator = tree:iter_rows(proxy, 1, #keys)
  tree.source:update(keys[2], { label = "replacement" })
  tree:insert(keys[2], { nodetype = "leaf", text = "replacement" })
  support.applied(tree:publish({ mode = "list", rootuuid = "root", orders = keys }))
  local count = 0
  for row, key, data, entry in iterator do
    count = count + 1
    t.assert_eq(count, row)
    t.assert_eq(keys[row], key)
    t.assert_eq(key, data.label)
    t.assert_eq(key, entry.text)
  end
  t.assert_eq(#keys, count)
  t.assert_eq(3, pages)
end)

t:test("row iteration resumes after short byte-limited pages without losing metadata or identities", function()
  local tree = fixture()
  local keys = {}
  for index = 1, 2500 do
    local key = (index <= 1024 and "short-" or string.rep("界", 600)) .. index
    keys[index] = key
    tree.source:insert("root", key, { label = tostring(index) })
    tree:insert(key, { nodetype = "leaf", text = tostring(index) })
  end
  support.applied(tree:publish({ mode = "list", rootuuid = "root", orders = keys }))
  local frame = tree:frame()
  local pages, count = 0, 0
  local proxy = setmetatable({}, {
    __index = function(_, name)
      return function(_, ...)
        if name == "row_keys" then
          pages = pages + 1
        end
        return frame[name](frame, ...)
      end
    end,
  })
  for row, key, data, entry in tree:iter_rows(proxy) do
    count = count + 1
    t.assert_eq(count, row)
    t.assert_eq(keys[row], key)
    t.assert_eq(tostring(row), data.label)
    t.assert_eq(tostring(row), entry.text)
  end
  t.assert_eq(#keys, count)
  t.assert_eq(4, pages, "short keys retain full pages and long keys consume only the required pages")
end)

t:test("range hiding preserves containers and outside marks while including file locations", function()
  local tree = fixture()
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

t:test("cold key and subtree reads export no full nodes or decorated rows", function()
  local tree = fixture()
  support.applied(tree:publish({ mode = "tree", rootuuid = "root" }))
  local frame = tree:frame()
  tree._versions[frame:header().data_revision].keys = {}
  local reads = 0
  local proxy = setmetatable({}, {
    __index = function(_, name)
      return function(_, ...)
        reads = reads + 1
        t.assert_false(name == "node" or name == "rows" or name == "flags", "structural reads must omit " .. name)
        return frame[name](frame, ...)
      end
    end,
  })
  t.assert_eq("dir", tree:retrieve_uuid(1, proxy))
  t.assert_eq(3, tree:retrieve_lastchild_lnum(1, proxy))
  t.assert_nil(tree:retrieve_lastchild_lnum(0, proxy))
  t.assert_nil(tree:retrieve_lastchild_lnum(-1, proxy))
  t.assert_nil(tree:retrieve_lastchild_lnum(5, proxy))
  t.assert_true(reads > 0, "the supplied Frame owns these reads")
end)

t:test("root and source parent reads follow the captured Frame rather than a pending root or producer", function()
  local tree = fixture()
  support.applied(tree:publish({ mode = "tree", rootuuid = "root" }))
  local original = tree:frame()
  support.applied(tree:publish({ mode = "tree", rootuuid = "dir" }))
  local nested = tree:frame()
  t.assert_eq(original:header().data_revision, nested:header().data_revision)
  t.assert_eq("root", tree:root_key(original))
  t.assert_eq("dir", tree:root_key(nested))
  tree.source:move("one", "root")
  t.assert_eq("dir", tree:parent_key("one", nested))
  t.assert_eq("root", tree:parent_key(tree:root_key(nested), nested))
  t.assert_nil(tree:parent_key("root", nested))
  t.assert_nil(tree:parent_key("missing", nested))
end)

t:test("range actions retain subtree and Visual semantics and release a throwing submission", function()
  local tree = fixture()
  local bufnr = vim.api.nvim_create_buf(false, true)
  local winnr = vim.api.nvim_open_win(bufnr, true, { relative = "editor", row = 0, col = 0, width = 40, height = 10 })
  t:defer(function()
    vim.cmd.normal({ args = { vim.keycode("<Esc>") }, bang = true })
    if vim.api.nvim_win_is_valid(winnr) then
      vim.api.nvim_win_close(winnr, true)
    end
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
  -- Read the minimum right after the view's own listener sets it: a later publication may already clear it.
  local minimum_commit
  dispatched:finally(function()
    minimum_commit = tree.view._minimum_commit
  end)
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
