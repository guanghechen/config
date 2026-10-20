local t = require("__test__.support.harness").new()
local Source = require("era.view.result_source")
local Snapshot = require("era.view.result_snapshot")

t:test("chunked metadata copying preserves shared references, cycles and metatables", function()
  local shared = setmetatable({ value = "before" }, { __index = { inherited = true } })
  shared.self = shared
  local source = Source.new("root", { label = "root", shared = shared })
  source:insert("root", "file", { label = "file", shared = shared })
  local entries = { file = { nodetype = "leaf", shared = shared, sentinel = vim.NIL } }
  local builder = Snapshot.new(source, entries, {}, function(_, data)
    return { label = data.label }
  end)
  while not builder:step() do
  end
  local snapshot = builder.snapshot
  local copy = snapshot.entries.file.shared
  t.assert_true(copy ~= shared)
  t.assert_true(copy == snapshot.data.root.shared and copy == snapshot.data.file.shared)
  t.assert_true(copy.self == copy)
  t.assert_true(getmetatable(copy) == getmetatable(shared))
  t.assert_true(copy.inherited)
  t.assert_true(snapshot.entries.file.sentinel == vim.NIL)
  shared.value = "after"
  t.assert_eq("before", copy.value)
end)

t:test("one file with thousands of locations yields during presentation and metadata copying", function()
  local source = Source.new("root", { label = "root" })
  source:insert("root", "file", { label = "file" })
  local entries = { file = { nodetype = "leaf", locations = {} } }
  for index = 1, 4000 do
    local key = "location:" .. index
    local entry = { nodetype = "location", locationuuid = key, leafuuid = "file", lnum = index }
    entries.file.locations[index], entries[key] = entry, entry
  end
  local builder = Snapshot.new(source, entries, {}, function(_, data, entry)
    return { label = entry.lnum and tostring(entry.lnum) or data.label }
  end)
  t.assert_false(builder:step(), "presentation must yield within a large file")
  t.assert_true(#builder.snapshot.records.keys < 4002)
  local steps = 1
  while not builder:step() do
    steps = steps + 1
  end
  t.assert_true(steps > 2)
  t.assert_eq(4002, #builder.snapshot.records.keys)
  t.assert_eq(4000, #builder.snapshot.entries.file.locations)
  t.assert_true(builder.snapshot.entries.file.locations[4000] == builder.snapshot.entries["location:4000"])
end)

t:test("presentation yields on its time budget before the record-count limit", function()
  local source = Source.new("root", { label = "root" })
  for index = 1, 100 do
    source:insert("root", tostring(index), { label = tostring(index) })
  end
  local clock = 0
  t:patch_table(vim.uv, "hrtime", function()
    clock = clock + 1000000
    return clock
  end)
  local builder = Snapshot.new(source, {}, {}, function(_, data)
    return { label = data.label }
  end)
  t.assert_false(builder:step())
  t.assert_eq(2, #builder.snapshot.records.keys)
end)

t:test("sparse snapshots and late topology changes preserve the complete input", function()
  local source = Source.new("root", { label = "root" })
  for index = 1, 600 do
    source:insert("root", "file:" .. index, { label = "file " .. index })
  end
  ---@param previous                    ?table
  ---@return table
  local function build(previous)
    local builder = Snapshot.new(source, {}, {}, function(_, data)
      return { label = data.label }
    end, previous)
    while not builder:step() do
    end
    return builder.snapshot
  end
  local initial = build()
  local previous = { topology = initial.topology, signatures = initial.signatures, revision = "r:1" }
  local same = build(previous)
  t.assert_eq(0, #same.updates)
  t.assert_nil(same.records, "unchanged input must not retain a full import payload")
  source:update("file:600", { label = "renamed" })
  local sparse = build(previous)
  t.assert_eq(1, #sparse.updates)
  t.assert_eq("file:600", sparse.updates[1].key)
  t.assert_nil(sparse.records)
  source:insert("root", "last", { label = "last" })
  local appended = build(previous)
  t.assert_nil(appended.updates)
  t.assert_eq(602, #appended.records.keys)
  t.assert_eq("file:1", appended.records.keys[2], "full import must include the unchanged prefix")
  t.assert_eq("renamed", appended.records.labels[601])
  t.assert_eq("last", appended.records.keys[602])
  source:remove("last")
  local removed = build({ topology = appended.topology, signatures = appended.signatures, revision = "r:2" })
  t.assert_nil(removed.updates)
  t.assert_eq(601, #removed.records.keys)
  t.assert_eq("renamed", removed.records.labels[601])
end)

t:test("flat metadata reuse preserves changed values and shared or distinct identities", function()
  local shared = { label = "file" }
  local source = Source.new("root", { label = "root" })
  source:insert("root", "one", shared)
  source:insert("root", "two", shared)
  local entries = { one = { nodetype = "leaf" }, two = { nodetype = "leaf" } }
  ---@param metadata                    ?table
  ---@return table
  local function build(metadata)
    local builder = Snapshot.new(source, entries, {}, function(_, data)
      return { label = data.label }
    end, nil, metadata)
    while not builder:step() do
    end
    return builder.snapshot
  end
  local initial = build()
  local same = build(initial)
  t.assert_true(same.data.one == initial.data.one and same.data.one == same.data.two)
  t.assert_true(same.entries.one == initial.entries.one)
  source:update("one", { label = "file" })
  source:update("two", { label = "file" })
  local distinct = build(same)
  t.assert_true(distinct.data.one ~= distinct.data.two, "equal values must not merge distinct producer objects")
  source:update("one", shared)
  source:update("two", shared)
  local reunited = build(distinct)
  t.assert_true(reunited.data.one == reunited.data.two)
  shared.label = "changed"
  entries.one.nodetype = "container"
  local changed = build(reunited)
  t.assert_eq("changed", changed.data.one.label)
  t.assert_eq("container", changed.entries.one.nodetype)
  t.assert_eq("file", initial.data.one.label)
  t.assert_eq("leaf", initial.entries.one.nodetype)
end)

t:run()
