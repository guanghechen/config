local t = require("__test__.support.harness").new()
local bootstrap = require("__test__.support.bootstrap")
bootstrap.with_native(t)
local reports = bootstrap.with_reporter(t)
local picker = require("__test__.support.picker")
local support = require("__test__.support.treeview")
local Source = require("era.view.result_source")

t:test("ordered List filtering retains Tree ancestors and native selection across imports", function()
  local tree = picker.branch_tree(t)
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

t:test("a publication collects Lua garbage in slices once the data retains past its floor", function()
  local tree = picker.branch_tree(t)
  local reclaims, reclaim = 0, tree._reclaim
  t:patch_table(tree, "_reclaim", function(self)
    reclaims = reclaims + 1
    return reclaim(self)
  end)
  support.applied(tree:publish({ mode = "list", rootuuid = "root" }))
  t.assert_true(reclaims > 0, "each publication checks")
  local MiB = 1024 * 1024
  local used = 0
  t:patch_table(tree._data, "native", function()
    return {
      retained_bytes = function()
        return used
      end,
    }
  end)
  -- A step finishes a cycle every third call and takes 2 ms, so a collection spans several 4 ms slices.
  local steps, collect = 0, collectgarbage
  t:patch_global("collectgarbage", function(option, ...)
    if option ~= "step" then
      return collect(option, ...)
    end
    steps = steps + 1
    vim.uv.sleep(2)
    return steps % 3 == 0
  end)
  ---@param bytes                       integer
  ---@return integer
  local function check(bytes)
    used = bytes
    tree:_reclaim()
    return steps
  end
  tree._memory_floor = nil
  t.assert_eq(0, check(100 * MiB))
  t.assert_eq(0, check(150 * MiB), "50 MiB past the floor is below 64 MiB")
  local first = check(170 * MiB)
  t.assert_true(first > 0 and first < 6, "the collection yields between slices")
  t.assert_eq(first, check(400 * MiB), "one collection at a time")
  t.wait_until(function()
    return steps == 6
  end, 5000)
  vim.wait(30)
  t.assert_eq(6, steps, "it ends with its second cycle")
  t.assert_eq(6, check(480 * MiB), "past a floor of 400 MiB, 80 MiB is below a quarter")
  check(500 * MiB)
  t.wait_until(function()
    return steps == 12
  end, 5000)
  t.assert_eq(12, check(105 * MiB))
  t.assert_eq(12, check(160 * MiB), "the floor follows the collection down")
  check(170 * MiB)
  t.wait_until(function()
    return steps == 18
  end, 5000)
end)

t:test("ready waits for every collapse change that is still in flight", function()
  local tree = picker.branch_tree(t)
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

t:test("an expansion change for a node a publication removed is dropped without an error", function()
  local tree = picker.branch_tree(t)
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
  tree:collapse("dir", "collapse", false)
  tree:set_expansion("dir", true, false)
  t.assert_eq(2, #releases, "both changes dispatched")

  -- The next publication no longer holds `dir` or its children.
  local source = Source.new("root", { label = "root" })
  source:insert("root", "three", { label = "three" })
  tree.source, tree.entries = source, {}
  tree:invalidate()
  tree:insert("root", { nodetype = "container" })
  tree:insert("three", { nodetype = "leaf", text = "three" })
  support.applied(tree:publish({ mode = "tree", rootuuid = "root" }))
  releases[1]()
  releases[2]()
  support.applied(tree:ready())

  t.assert_eq("three", tree:retrieve_uuid(1), "the published rows")
  t.assert_same({}, reports.error)
end)

t:test("input deferred behind a collapse decides on the Frame that shows it", function()
  local tree = picker.branch_tree(t)
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
  local tree = picker.branch_tree(t)
  local bufnr = t:buffer()
  local winnr = t:window(bufnr, { relative = "editor", row = 0, col = 0, width = 40, height = 10 })
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
  end, 5000, "ready must settle once the publication finishes")
  t.assert_eq("Applied", ready:get_result().kind)
end)

t:test("a native surface keeps old metadata until publication and survives reopening", function()
  local tree = picker.branch_tree(t)
  local bufnr = t:buffer()
  local winnr = t:window(bufnr, { relative = "editor", row = 0, col = 0, width = 40, height = 10 })
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
  local next_bufnr = t:buffer()
  winnr = t:window(next_bufnr, { relative = "editor", row = 0, col = 0, width = 40, height = 10 })
  tree:mount(winnr, next_bufnr, function() end)
  t.wait_until(function()
    return tree.view and tree.view:frame() ~= nil
  end, 5000)
  t.assert_true(tree.state == identity)
  t.assert_eq("new", tree:data("one").label)
  t.assert_same({}, reports.error)
end)

t:test("an idle result retains native notifications without another Lua Future", function()
  local tree = picker.branch_tree(t)
  local bufnr = t:buffer()
  local winnr = t:window(bufnr, { relative = "editor", row = 0, col = 0, width = 40, height = 10 })
  tree:mount(winnr, bufnr, function() end)
  support.applied(tree:publish({ mode = "tree", rootuuid = "root" }))
  -- Let the poll loop go idle; if it is still running, the check below is weaker, not wrong.
  vim.wait(30)
  local ticket = tree.state:native():dispatch({
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
  local tree = picker.branch_tree(t)
  local first = tree:publish({ mode = "list", orders = { "one" } })
  local second = tree:publish({ mode = "list", orders = { "three" } })
  t.assert_eq("Superseded", first:get_result().kind)
  support.applied(second)
  t.assert_eq(1, tree:linecount())
  t.assert_eq("three", tree:retrieve_uuid(1))
  t.assert_same({}, reports.error)
end)

t:test("a producer change during preparation supersedes the partial snapshot", function()
  local tree = picker.branch_tree(t)
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
  local tree = picker.branch_tree(t)
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
  local tree = picker.branch_tree(t)
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
    local tree = picker.branch_tree(t)
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

t:test("a result tree imports more records than one native batch holds by default", function()
  local source = Source.new("root", { label = "root" })
  local tree = picker.result_tree(t, "many results", source)
  tree:insert("root", { nodetype = "container" })
  for index = 1, 200001 do
    local key = "node-" .. index
    source:insert("root", key, { label = key })
    tree:insert(key, { nodetype = "leaf", text = key })
  end
  support.applied(tree:publish({ mode = "tree", rootuuid = "root" }))
  t.assert_eq(200001, tree:frame():header().row_count)
end)

t:run()
