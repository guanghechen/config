local harness = require("__test__.support.harness")
local bootstrap = require("__test__.support.bootstrap")
local t = harness.new()
bootstrap.with_native(t)
local treeview = require("ux.treeview")
local support = require("__test__.support.treeview")
local fixture = support.fixture

t:test("owned input, identity, atomic failure, and exact recursive option", function()
  local data, state, a = fixture()
  local old = state:snapshot()
  local input = { { kind = "update", id = a, label = "changed", fields = { path = "old" } } }
  local future = data:batch(input)
  input[1].label = "mutated after import"
  input[1].fields.path = "mutated"
  support.applied(future)
  t.assert_eq("changed", data:source():node(a).label)
  t.assert_eq("old", data:source():node(a).fields.path)
  t.assert_eq("alpha", old:node(a).label)
  local invalid = t.await(state:select_node({ a }, "true"))
  t.assert_eq("Rejected", invalid.kind)
  t.assert_eq("InvalidUpdate", invalid.error.code)
  support.applied(state:select_node({ a }, false))
  local inspect = t.await(state:inspect_selection())
  t.assert_eq(1, inspect.summary.known_roots)
  local base = data:source():revision()
  invalid = t.await(data:batch({
    { kind = "update", id = a, label = "not committed" },
    { kind = "insert", key = "a", label = "duplicate" },
  }))
  t.assert_eq("Rejected", invalid.kind)
  t.assert_eq(base, data:source():revision())
  t.assert_eq("changed", data:source():node(a).label)
end)

t:test("viewport guide output is bounded without invalidating the immutable frame", function()
  local data = treeview.new_data()
  local records = { { key = "root", label = "root", can_expand = true } }
  local parent = "root"
  for index = 1, 256 do
    local key = "branch" .. index
    records[#records + 1] = { key = key, parent = parent, label = key, can_expand = true }
    records[#records + 1] = { key = "sibling" .. index, parent = parent, label = "sibling" }
    parent = key
  end
  for index = 1, 40 do
    records[#records + 1] = { key = "leaf" .. index, parent = parent, label = "leaf" }
  end
  support.applied(data:import(records))
  local source = data:source()
  local state = t.await(data:create_state({ kind = "children_of", node = source:id("root") }))
  support.applied(state:set_expanded({ source:id("root") }, true, true))
  local frame
  t.wait_until(function()
    frame = state:snapshot()
    return frame:position(source:id("leaf40")) ~= nil
  end, 5000)
  local first, last = frame:position(source:id("leaf1")), frame:position(source:id("leaf40"))
  local ok, error = pcall(frame.rows, frame, first, last)
  t.assert_false(ok)
  t.assert_true(tostring(error):find("ResourceLimit", 1, true) ~= nil, tostring(error))
  t.assert_eq("leaf", frame:rows(first, first).labels[1])
  t.assert_eq(source:id("leaf40"), frame:node_at(last))
end)

t:test("nil, empty, and partial render contexts share default geometry", function()
  local _, state = fixture()
  local view = state._native:attach()
  t:defer(function()
    view:detach()
  end)
  local async = require("ux.treeview.async")
  local frame = state:snapshot()
  local default = t.await(async.run(view:plan(nil, frame, nil, nil, true)))
  local expected = default:lines(0, 2, 1024)
  t.assert_same({ "    alpha", "    beta" }, expected)
  for _, context in ipairs({ {}, { separator = "/" }, { indent = 2 }, { slots = 2 } }) do
    local plan = t.await(async.run(view:plan(nil, frame, context, nil, true)))
    local lines = plan:lines(0, 2, 1024)
    t.assert_same(expected, lines)
  end
end)

t:test("column length failure preserves the previous source", function()
  local data = treeview.new_data()
  support.applied(data:import({ keys = { "x", "y" }, labels = { "X", "Y" }, parents = { 0, 0 } }))
  local revision = data:source():revision()
  local result = t.await(data:import({ keys = { "z", "w" }, labels = { "Z" } }))
  t.assert_eq("Rejected", result.kind)
  t.assert_eq(revision, data:source():revision())
end)

t:test("sparse arrays are rejected before changing source or selection", function()
  local data, state, a = fixture()
  support.applied(state:select_node({ a }, false))
  local revision = data:source():revision()
  for _, records in ipairs({
    { [0] = { key = "bad", label = "bad" } },
    { [100] = { key = "bad", label = "bad" } },
    { keys = { [100] = "bad" }, labels = { [100] = "bad" } },
    { keys = { "bad" }, labels = { "bad" }, parents = { [100] = 0 } },
  }) do
    t.assert_eq("Rejected", t.await(data:import(records)).kind)
    t.assert_eq(revision, data:source():revision())
    t.assert_eq(a, data:source():id("a"))
  end
  t.assert_eq("Rejected", t.await(data:batch({ [100] = { kind = "remove", id = a } })).kind)
  t.assert_eq("Rejected", t.await(state:select_node({ [100] = a }, false)).kind)
  t.assert_eq(1, t.await(state:inspect_selection()).summary.known_roots)
  local upload = data:begin_import()
  t.assert_eq("Rejected", upload:append({ [100] = { key = "bad", label = "bad" } }).kind)
  t.assert_eq("Rejected", t.await(upload:commit()).kind)
  local oversized = data:begin_import()
  t.assert_eq("Rejected", oversized:append({ { key = "large", label = string.rep("x", 2 * 1024 * 1024) } }).kind)
  t.assert_eq(revision, data:source():revision())
end)

t:test("decoration capacity failure preserves the previous publication", function()
  local data, state, a = fixture()
  -- Regex ranges list every occurrence; fuzzy ranges are one alignment per label.
  support.applied(state:set_display({ pattern = "a", regex = true }))
  local errors = {}
  local view = treeview.attach(state, {
    keymaps = false,
    on_error = function(err)
      errors[#errors + 1] = err
    end,
  })
  t:defer(function()
    view:detach()
  end)
  t.wait_until(function()
    return view:frame() ~= nil
  end, 5000)
  local frame, tick = view:frame():id(), vim.api.nvim_buf_get_changedtick(view.bufnr)
  support.applied(data:batch({ { kind = "update", id = a, label = string.rep("a", 10000) } }))
  t.wait_until(function()
    return #errors > 0
  end, 5000)
  vim.wait(50, function()
    return false
  end)
  t.assert_eq(1, #errors)
  t.assert_eq(tick, vim.api.nvim_buf_get_changedtick(view.bufnr))
  t.assert_eq(frame, view:frame():id())
  support.applied(data:batch({ { kind = "update", id = a, label = "alpha" } }))
  t.wait_until(function()
    return not view:status().error and state._native:applicable(view:frame(), nil)
  end, 5000)
end)

t:test("row key pages and subtree boundaries omit row payloads and keep retained frame order", function()
  local data = treeview.new_data()
  local records = { { key = "root", label = "root", can_expand = true } }
  for index = 1, 1025 do
    records[#records + 1] = { key = "key-" .. index, parent = "root", label = string.rep("x", 4096) }
  end
  support.applied(data:import(records))
  local source = data:source()
  local state = t.await(data:create_state({ kind = "forest", nodes = { source:id("root") } }))
  support.applied(state:set_expanded({ source:id("root") }, true, false))
  t.wait_until(function()
    return state:snapshot():header().row_count == 1026
  end, 5000)
  local frame = state:snapshot()
  t.assert_eq(1026, frame:header().row_count)
  t.assert_eq(1026, frame:subtree_end(1))
  t.assert_eq(2, frame:subtree_end(2))
  t.assert_nil(frame:subtree_end(0))
  t.assert_nil(frame:subtree_end(1027))
  t.assert_false(pcall(frame.rows, frame, 2, 513), "decorated rows exceed their byte budget")
  local keys = frame:row_keys(2, 1025)
  t.assert_eq(1024, #keys)
  t.assert_eq("key-1", keys[1])
  t.assert_eq("key-1024", keys[1024])
  t.assert_eq("key-1025", frame:row_keys(1026, 1026)[1])
  t.assert_eq(0, #frame:row_keys(1, 0))
  for _, bounds in ipairs({ { 0, 1 }, { 2, 1026 }, { 1, 1027 }, { 3, 1 } }) do
    t.assert_false(pcall(frame.row_keys, frame, bounds[1], bounds[2]))
  end
  support.applied(state:set_expanded({ source:id("root") }, false, false))
  t.wait_until(function()
    return state:snapshot():header().row_count == 1
  end, 5000)
  t.assert_eq(1, state:snapshot():subtree_end(1))
  t.assert_eq(1026, frame:subtree_end(1))
  support.applied(data:batch({ { kind = "remove", id = source:id("key-1") } }))
  t.assert_eq("key-1", frame:row_keys(2, 2)[1])
  support.applied(state:set_display({ mode = "list", filter = { source:id("key-3"), source:id("key-2") } }))
  t.wait_until(function()
    return state:snapshot():header().row_count == 2
  end, 5000)
  local list = state:snapshot()
  t.assert_same({ "key-3", "key-2" }, list:row_keys(1, 2))
  t.assert_eq(1, list:subtree_end(1))
  t.assert_eq(2, list:subtree_end(2))
  t.assert_eq(0, #list:row_keys(3, 2))
end)

t:test("row key pages resume at the byte boundary while explicit node key reads stay strict", function()
  local data = treeview.new_data()
  local records = {}
  for index = 1, 600 do
    records[index] = { key = string.rep("界", 600) .. index, label = "small" }
  end
  support.applied(data:import(records))
  local nodes = {}
  for index, record in ipairs(records) do
    nodes[index] = data:source():id(record.key)
  end
  local state = t.await(data:create_state({ kind = "forest", nodes = nodes }))
  local frame = state:snapshot()
  t.assert_eq(512, #frame:row_keys(1, 512))
  local keys = frame:row_keys(1, 600)
  t.assert_true(#keys > 0 and #keys < 600)
  local bytes = 0
  for index, key in ipairs(keys) do
    t.assert_eq(records[index].key, key)
    bytes = bytes + #key
  end
  t.assert_true(bytes <= 1024 * 1024)
  t.assert_true(bytes + #records[#keys + 1].key > 1024 * 1024, "each page fills its byte budget")
  support.applied(data:batch({ { kind = "remove", id = nodes[#keys + 1] } }))
  local rest = frame:row_keys(#keys + 1, 600)
  t.assert_eq(600, #keys + #rest)
  for index, key in ipairs(rest) do
    t.assert_eq(records[#keys + index].key, key)
  end
  local ok, error = pcall(frame.node_keys, frame, nodes)
  t.assert_false(ok)
  t.assert_true(tostring(error):find("1 MiB", 1, true) ~= nil, tostring(error))
end)

t:test("Source key and parent reads retain identity after removal without node payloads", function()
  local data, _, a, b = fixture()
  local source = data:source()
  local root = source:id("root")
  t.assert_eq("a", source:key(a))
  t.assert_eq(root, source:parent(a))
  t.assert_nil(source:parent(root))
  support.applied(data:batch({ { kind = "remove", id = a } }))
  local current = data:source()
  t.assert_nil(current:key(a))
  t.assert_nil(current:parent(a))
  t.assert_eq("b", current:key(b))
  t.assert_eq("a", source:key(a))
  t.assert_eq(root, source:parent(a))
end)

t:test("key pages accept the exact byte limit and reject a single oversized identity without empty progress", function()
  local data = treeview.new_data()
  local exact = string.rep("k", 1024 * 1024)
  local oversized = exact .. "x"
  support.applied(data:import({
    { key = "short", label = "short" },
    { key = exact, label = "exact" },
    { key = oversized, label = "oversized" },
  }))
  local source = data:source()
  local state = t.await(data:create_state({
    kind = "forest",
    nodes = { source:id("short"), source:id(exact), source:id(oversized) },
  }))
  local frame = state:snapshot()
  t.assert_same({ "short" }, frame:row_keys(1, 3))
  local page = frame:row_keys(2, 3)
  t.assert_eq(1, #page)
  t.assert_eq(exact, page[1])
  local ok, error = pcall(frame.row_keys, frame, 3, 3)
  t.assert_false(ok)
  t.assert_true(tostring(error):find("1 MiB", 1, true) ~= nil, tostring(error))
end)

t:run()
