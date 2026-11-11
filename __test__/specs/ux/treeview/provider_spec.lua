local harness = require("__test__.support.harness")
local bootstrap = require("__test__.support.bootstrap")
local t = harness.new()
bootstrap.with_native(t)
local treeview = require("ux.treeview")
local support = require("__test__.support.treeview")

t:test("List loads a hidden unknown root and activation preserves Tree expansion", function()
  local calls, activated = 0, nil
  local data = treeview.new_data({
    read_children = function()
      calls = calls + 1
      return {
        records = { { key = "branch", label = "branch", can_expand = true, completeness = "complete" } },
        done = true,
      }
    end,
  })
  support.applied(data:batch({ { kind = "insert", key = "root", label = "root", can_expand = true } }))
  t.assert_eq("unknown", data:source():node(data:source():id("root")).completeness)
  local state = t.await(data:create_state({ kind = "children_of", node = data:source():id("root") }, { mode = "list" }))
  local view = support.attach(t, state, {
    keymaps = false,
    on_activate = function(_, node)
      activated = node
    end,
  })
  t.wait_until(function()
    return view:frame() and view:status().frame.row_count == 1
  end, 5000)
  t.assert_eq(1, calls)
  view:activate()
  t.assert_eq(data:source():id("branch"), activated)
  t.assert_false(state:snapshot():rows(1, 1).expanded[1])
end)

t:test("PrepareSources Pending finishes once and a task alone can request children", function()
  local Future = require("stl.c.future")
  local read, resolve = Future.new_with_resolver()
  local calls = 0
  local data = treeview.new_data({
    read_children = function()
      calls = calls + 1
      return read
    end,
  })
  support.applied(data:batch({ { kind = "insert", key = "root", label = "root", can_expand = true } }))
  local root = data:source():id("root")
  local state = t.await(data:create_state({ kind = "children_of", node = root }))
  support.applied(state:select_node({ root }, false))
  local task = t.await(state:lock_selection(5000))
  local pending = task:prepare_sources()
  t.assert_eq("Pending", t.await(pending).kind)
  t.wait_until(function()
    return calls == 1
  end, 5000)
  resolve({ records = { { key = "child", label = "child" } }, done = true })
  t.wait_until(function()
    return data:source():node(root).completeness == "complete"
  end, 5000)
  local ready = t.await(task:prepare_sources())
  t.assert_eq("Ready", ready.kind, vim.inspect(ready))
  t.assert_eq(0, ready.subtree_roots:len())
  t.assert_eq(1, ready.self_only_nodes:len())
  t.assert_eq("Pending", pending:get_result().kind)
  support.applied(data:batch({ { kind = "update", id = root, label = "new label" } }))
  t.assert_eq("root", ready.source:node(root).label)
  t.assert_eq("root", t.await(task:prepare_sources()).source:node(root).label)
  support.applied(task:unlock())
end)

t:test("query generations coalesce pending work and retain only the new result set", function()
  local Future = require("stl.c.future")
  local data = treeview.new_data({ limits = { concurrent_reads = 1 } })
  support.applied(data:import({ { key = "old", label = "old" } }))
  local provider = t.await(data:create_provider({ kind = "forest" }))
  local requests, resolvers = {}, {}
  local query = t.await(provider:create_query(function(request)
    requests[#requests + 1] = request
    local future, resolve = Future.new_with_resolver()
    resolvers[#resolvers + 1] = resolve
    return future
  end))
  support.applied(query:start({ pattern = "a" }))
  t.wait_until(function()
    return #requests == 1
  end, 5000)
  support.applied(query:start({ pattern = "ab" }))
  support.applied(query:start({ pattern = "abc" }))
  t.wait_until(function()
    return requests[1].is_cancelled()
  end, 5000)
  resolvers[1]({ records = { { key = "stale", label = "stale" } }, done = true })
  t.wait_until(function()
    return #requests == 2
  end, 5000)
  t.assert_eq("abc", requests[2].pattern)
  t.assert_nil(data:source():id("stale"))
  resolvers[2]({ records = { { key = "new", label = "new" } }, done = true })
  t.wait_until(function()
    return data:source():id("new") ~= nil
  end, 5000)
  t.assert_nil(data:source():id("old"))
  t.assert_eq("complete", query:info().completeness)
  local result = data:source():query_result({ kind = "forest" })
  t.assert_eq("abc", result.pattern)
  t.assert_eq(query:info().result_generation, result.generation)
end)

t:test("private chunks retain ownership and publish only on commit", function()
  local data = treeview.new_data()
  local upload = data:begin_import()
  local chunk = { keys = { "root" }, labels = { "root" }, can_expand = { true } }
  t.assert_eq("NoChange", upload:append(chunk).kind)
  chunk.labels[1] = "changed by caller"
  t.assert_eq(0, data:source():len())
  t.assert_eq("NoChange", upload:append({ keys = { "child" }, labels = { "child" }, parent_keys = { "root" } }).kind)
  support.applied(upload:commit())
  t.assert_eq("root", data:source():node(data:source():id("root")).label)
  t.assert_eq(2, data:source():len())
  local revision = data:source():revision()
  local bad = data:begin_import()
  t.assert_eq("NoChange", bad:append({ { key = "new", label = "new" } }).kind)
  t.assert_eq("Rejected", bad:append({ keys = { "x" }, labels = {} }).kind)
  t.assert_eq("Rejected", t.await(bad:commit()).kind)
  t.assert_eq(revision, data:source():revision())
end)

t:test("provider failures preserve classification for children and queries", function()
  local cases = {
    {
      value = { error = { code = "NotFound", message = "resource absent" } },
      code = "NotFound",
      message = "resource absent",
    },
    {
      value = { error = { code = "ProviderError", message = "permission denied" } },
      code = "ProviderError",
      message = "permission denied",
    },
    { value = { error = "cannot read" }, code = "ProviderError", message = "cannot read" },
    { thrown = true, code = "ProviderError", message = "provider threw" },
    {
      rejected = true,
      value = "async denied",
      code = "ProviderError",
      message = "async denied",
    },
    { value = 42, code = "InvalidUpdate" },
    { value = {}, code = "InvalidUpdate" },
    { value = { error = { code = "ENOENT", message = "bad code" } }, code = "InvalidUpdate" },
  }
  for _, case in ipairs(cases) do
    local handler = function()
      if case.thrown then
        error("provider threw", 0)
      end
      if case.rejected then
        return require("stl.c.future").reject(case.value)
      end
      return case.value
    end
    local data = treeview.new_data({ read_children = handler })
    support.applied(data:batch({ { kind = "insert", key = "root", label = "root", can_expand = true } }))
    local root = data:source():id("root")
    support.applied(data:request_children({ root }))
    t.wait_until(function()
      return data:source():node(root).load_state == "error"
    end, 5000)
    local failure = data:source():node(root).error
    t.assert_eq(case.code, failure.code)
    if case.message then
      t.assert_eq(case.message, failure.message)
    end
    local query_data = treeview.new_data()
    local provider = t.await(query_data:create_provider({ kind = "forest" }))
    local query = t.await(provider:create_query(handler))
    support.applied(query:start({ pattern = "test" }))
    t.wait_until(function()
      return query:info().error ~= nil
    end, 5000)
    failure = query:info().error
    t.assert_eq(case.code, failure.code)
    if case.message then
      t.assert_eq(case.message, failure.message)
    end
  end
end)

t:test("malformed provider errors still end their reserved read and release a preparing task", function()
  local Future = require("stl.c.future")
  local read, fail = Future.new_with_resolver()
  local data = treeview.new_data({
    read_children = function()
      return read
    end,
  })
  support.applied(data:batch({ { kind = "insert", key = "root", label = "root", can_expand = true } }))
  local root = data:source():id("root")
  local state = t.await(data:create_state({ kind = "children_of", node = root }))
  support.applied(state:select_node({ root }, false))
  local task = t.await(state:lock_selection(5000))
  t.assert_eq("Pending", t.await(task:prepare_sources()).kind)
  fail({ error = { code = "ENOENT", message = "provider error" } })
  t.wait_until(function()
    return not state:status().locked
  end, 5000)
  t.assert_eq("error", data:source():node(root).load_state)
  t.assert_eq("InvalidUpdate", data:source():node(root).error.code)
end)

t:test("List ancestry text remains specific to each root", function()
  local data = treeview.new_data()
  support.applied(data:import({
    { key = "root", label = "root", can_expand = true },
    { key = "src", parent = "root", label = "src", can_expand = true },
    { key = "leaf", parent = "src", label = "文.lua" },
  }))
  local source = data:source()
  local outer = t.await(
    data:create_state({ kind = "children_of", node = source:id("root") }, { mode = "list", list_text = "ancestry" })
  )
  local inner = t.await(
    data:create_state({ kind = "children_of", node = source:id("src") }, { mode = "list", list_text = "ancestry" })
  )
  local old = outer:snapshot()
  t.assert_same({ "src", "src/文.lua" }, old:rows(1, 2).labels)
  t.assert_eq("文.lua", inner:snapshot():rows(1, 1).labels[1])
  support.applied(data:batch({ { kind = "update", id = source:id("src"), label = "renamed" } }))
  t.wait_until(function()
    return outer:snapshot():rows(2, 2).labels[1] == "renamed/文.lua"
  end, 5000)
  t.assert_eq("文.lua", inner:snapshot():rows(1, 1).labels[1])
  t.assert_same({ "src", "src/文.lua" }, old:rows(1, 2).labels)
  local invalid = t.await(
    data:create_state({ kind = "children_of", node = source:id("root") }, { mode = "list", list_text = "unknown" })
  )
  t.assert_eq("Rejected", invalid.kind)
  t.assert_eq("InvalidUpdate", invalid.error.code)
end)

t:test("directory import refreshes ancestry text in the published buffer", function()
  local data = treeview.new_data()
  local records = {
    { key = "root", label = "root", can_expand = true },
    { key = "dir", parent = "root", label = "before", can_expand = true },
    { key = "file", parent = "dir", label = "文.lua" },
  }
  support.applied(data:import(records))
  local state = t.await(
    data:create_state(
      { kind = "children_of", node = data:source():id("root") },
      { mode = "list", list_text = "ancestry", show_hidden = false }
    )
  )
  local view = support.attach(t, state, { keymaps = false })
  t.wait_until(function()
    return view:frame() ~= nil
  end, 5000)
  local old = view:frame()
  records[2].label = "after"
  local reply = support.applied(data:import(records))
  t.wait_until(function()
    return state:native():applicable(view:frame(), reply.revisions.commit)
  end, 5000)
  t.assert_same({ "  after", "  after/文.lua" }, vim.api.nvim_buf_get_lines(view.bufnr, 0, -1, true))
  t.assert_same({ "before", "before/文.lua" }, old:rows(1, 2).labels)
end)

t:run()
