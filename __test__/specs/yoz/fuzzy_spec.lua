local harness = require("__test__.support.harness")
local bootstrap = require("__test__.support.bootstrap")
local t = harness.new()
local native = bootstrap.with_native(t)
local treeview = require("ux.treeview")

---A corpus whose items are their own keys, so results read back as texts.
---@param texts                         string[]
---@param scheme                        ?yoz.fuzzy.Scheme
---@return yoz.fuzzy.Corpus
local function corpus(texts, scheme)
  local value = native.fuzzy.new_corpus({ scheme = scheme or "path" })
  value:append(texts, texts)
  return value
end

---@param value                         yoz.fuzzy.Corpus
---@param query                         yoz.fuzzy.IQuery
---@return string[]
local function matched(value, query)
  local keys = value:query(query):keys()
  table.sort(keys)
  return keys
end

t:test("queries rank matches as fzf's path scheme and slice them by rank", function()
  local value = corpus({ "a/b/foo.lua", "foo/bar.lua", "x/foo.lua", "xx/foo.lua", "foo.lua", "readme.md" })
  local result = value:query({ pattern = "foo" })
  t.assert_eq(5, result:count())
  local expected = { "foo.lua", "x/foo.lua", "xx/foo.lua", "a/b/foo.lua", "foo/bar.lua" }
  t.assert_same(expected, result:keys(), vim.inspect(result:keys()))
  t.assert_same({ "x/foo.lua", "xx/foo.lua" }, result:keys(2, 3))
  t.assert_same({}, result:keys(4, 3))
end)

t:test("an empty pattern keeps every item in order", function()
  t.assert_same({ "b", "a", "c" }, corpus({ "b", "a", "c" }, "default"):query({ pattern = "   " }):keys())
end)

t:test("case modes, exact matching and the extended syntax select matches", function()
  local value = corpus({ "src/Core.lua", "src/core.lua", "lib/core_test.lua", "doc/core.md" })
  t.assert_same({ "src/Core.lua" }, matched(value, { pattern = "Core" }))
  t.assert_eq(4, #matched(value, { pattern = "core" }))
  t.assert_eq(4, #matched(value, { pattern = "Core", case = "ignore" }))
  t.assert_eq(3, #matched(value, { pattern = "core", case = "respect", fuzzy = false, rank = false }))
  t.assert_same({ "src/core.lua" }, matched(value, { pattern = "src/core", case = "respect" }))
  t.assert_eq(0, #matched(value, { pattern = "cre", fuzzy = false }))
  t.assert_eq(4, #matched(value, { pattern = "cre" }))
  t.assert_same({ "doc/core.md" }, matched(value, { pattern = "core md$" }))
  t.assert_same({ "lib/core_test.lua" }, matched(value, { pattern = "^lib | ^zzz" }))
  t.assert_eq(3, #matched(value, { pattern = "core !test" }))
  t.assert_same({ "doc/core.md", "src/core.lua" }, matched(value, { pattern = "core !test !Core" }))
end)

t:test("weights reorder close scores", function()
  local value = corpus({ "lib/foo.lua", "src/foo.lua" })
  t.assert_same({ "lib/foo.lua", "src/foo.lua" }, value:query({ pattern = "foo" }):keys())
  value:set_weights(string.char(0, 100))
  t.assert_same({ "src/foo.lua", "lib/foo.lua" }, value:query({ pattern = "foo", weight = 32 }):keys())
  t.assert_same({ "src/foo.lua", "lib/foo.lua" }, value:query({ pattern = "", weight = 1 }):keys())
  t.assert_false(pcall(value.set_weights, value, string.char(1)))
end)

t:test("highlights are byte ranges of the original text, only for matched items", function()
  local text = "文档/café_core.rs"
  local value = corpus({ text, "src/core.rs" })
  local result = value:query({ pattern = "cfcore" })
  t.assert_same({ text }, result:keys())
  local highlighted = {}
  for _, point in ipairs(assert(result:highlight(text))) do
    highlighted[#highlighted + 1] = text:sub(point.l + 1, point.r)
  end
  t.assert_eq("cfcore", table.concat(highlighted))
  t.assert_true(result:has(text))
  t.assert_false(result:has("src/core.rs"))
  t.assert_nil(result:highlight("src/core.rs"))
  t.assert_nil(result:highlight("missing"))
end)

t:test("each item needs keys; its first key names it", function()
  local value = native.fuzzy.new_corpus({ scheme = "path" })
  t.assert_false(pcall(value.append, value, { "a" }))
  t.assert_false(pcall(value.append, value, { "a", "b" }, { "item:a" }))
  t.assert_false(pcall(value.append, value, { "a" }, { {} }))
  value:append({ "src/alpha.lua", "src/beta.lua" }, { "item:a", { "item:b", "item:b:1" } })
  local result = value:query({ pattern = "beta" })
  t.assert_same({ "item:b" }, result:keys())
  t.assert_same({ { l = 4, r = 8 } }, result:highlight("item:b"), vim.inspect(result:highlight("item:b")))
  t.assert_false(result:has("item:a"))
  t.assert_false(result:has("item:b:1"))
end)

t:test("same results compare equal and differ across corpora", function()
  local value = corpus({ "alpha", "beta" }, "default")
  local first, second = value:query({ pattern = "a" }), value:query({ pattern = "a" })
  t.assert_true(first:same(second))
  t.assert_false(first:same(value:query({ pattern = "b" })))
  t.assert_false(first:same(corpus({ "alpha", "beta" }, "default"):query({ pattern = "a" })))
end)

t:test("result ids filter a treeview in rank order with the nodes shown under each item", function()
  local data = treeview.new_data()
  local records = { { key = "root", label = "root", can_expand = true } }
  local items, keys = {}, {}
  for index, name in ipairs({ "lib/foo.lua", "src/bar.lua", "foo.lua", "doc/zzz.md" }) do
    local key = "item:" .. index
    records[#records + 1] = { key = key, parent = "root", label = name, can_expand = index == 1 }
    items[#items + 1], keys[#keys + 1] = name, key
  end
  records[#records + 1] = { key = "item:1:location", parent = "item:1", label = "location" }
  keys[1] = { "item:1", "item:1:location", "item:missing" }
  t.assert_eq("Applied", t.await(data:import(records)).kind)
  local value = native.fuzzy.new_corpus({ scheme = "path" })
  value:append(items, keys)
  local source = data:source()
  local result = value:query({ pattern = "foo" })
  local ids = result:ids(source)
  t.assert_eq(3, ids:len())
  t.assert_eq(source:id("item:3"), ids:get(1))
  t.assert_eq(source:id("item:1"), ids:get(2))
  t.assert_eq(source:id("item:1:location"), ids:get(3))
  t.assert_true(rawequal(ids, ids) and result:ids(source):len() == 3)

  local state = t.await(data:create_state({ kind = "children_of", node = source:id("root") }, {
    mode = "list",
    filter = ids,
  }))
  t.assert_eq("table", type(state), vim.inspect(state))
  vim.wait(5000, function()
    return state:snapshot():header().row_count == 3
  end)
  local frame = state:snapshot()
  local rows = frame:row_keys(1, frame:header().row_count)
  t.assert_same({ "item:3", "item:1", "item:1:location" }, rows)
end)

t:test("an id handle carries more ids than a Lua array input may", function()
  local count = 70000
  local data = treeview.new_data()
  local upload = data:begin_import()
  local root = { keys = { "root" }, parent_keys = { false }, labels = { "root" }, can_expand = { true } }
  t.assert_eq("NoChange", upload:append(root).kind)
  local items, keys = {}, {}
  for first = 1, count, 512 do
    local columns = { keys = {}, parent_keys = {}, labels = {} }
    for index = first, math.min(first + 511, count) do
      local key = "n" .. index
      columns.keys[#columns.keys + 1], columns.parent_keys[#columns.keys + 1] = key, "root"
      columns.labels[#columns.labels + 1] = key
      -- Three ids per item exceed the 200k Lua array limit with 70k nodes.
      items[index], keys[index] = "dir/file" .. index .. ".lua", { key, key, key }
    end
    local reply = upload:append(columns)
    t.assert_eq("NoChange", reply.kind, vim.inspect(reply))
  end
  local committed = t.await(upload:commit())
  t.assert_eq("Applied", committed.kind, vim.inspect(committed))
  local value = native.fuzzy.new_corpus({ scheme = "path" })
  value:append(items, keys)
  local source = data:source()
  local ids = value:query({ pattern = "file" }):ids(source)
  t.assert_eq(3 * count, ids:len())
  local state = t.await(data:create_state({ kind = "children_of", node = source:id("root") }, {
    mode = "list",
    filter = ids,
  }))
  t.assert_eq("table", type(state), vim.inspect(state))
  t.wait_until(function()
    return state:snapshot():header().row_count == count
  end, 10000, "filtered rows")
end)

t:run()
