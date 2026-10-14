local harness = require("__test__.support.harness")
local runtime = require("__test__.fixtures.era.keystroke.cmp.runtime")
runtime.setup()
local t = harness.new("era.keystroke.cmp.rank")
local Rank = require("era.keystroke.cmp.rank")
local Item = require("era.keystroke.cmp.item")
local Reference = require("__test__.fixtures.era.keystroke.cmp.rank_reference")

t:test("native snapshots reject inconsistent metadata and eligibility without damaging later queries", function()
  local data = {
    labels = { "alpha" },
    filters = { "alpha" },
    sort_texts = { "alpha" },
    ids = { "alpha" },
    frecency_keys = { "lsp\0alpha" },
    offsets = { 0 },
    deprecated = { false },
    regions = { 1 },
    filetypes = { "lua" },
  }
  for _, invalid in ipairs({
    { ids = {} },
    { regions = { 0 } },
    { regions = { 2 } },
    { offsets = { math.huge } },
    { labels = { "\255" } },
    { filters = { "\255" } },
    { sort_texts = { "\255" } },
    { sort_texts = { true } },
    { sort_texts = { 1 } },
    { filetypes = { "\255" } },
  }) do
    local ok = pcall(yoz.completion.new_snapshot, vim.tbl_extend("force", data, invalid))
    t.assert_eq(false, ok, "invalid metadata rejected")
  end
  local snapshot = yoz.completion.new_snapshot(data)
  local ok = pcall(yoz.completion.rank, { { snapshot = snapshot, query = "al", eligible = {} } }, "")
  t.assert_eq(false, ok, "mask must cover every region")
  local groups, indexes = yoz.completion.rank({ { snapshot = snapshot, query = "al", eligible = { true } } }, "")
  t.assert_true(vim.deep_equal({ 1 }, groups), "valid query remains usable")
  t.assert_true(vim.deep_equal({ 1 }, indexes), "candidate remains available")
end)

t:test("opaque native identities preserve input order, deduplication and accepted history", function()
  local snapshot = yoz.completion.new_snapshot({
    labels = { "alpha", "alpha", "alpha" },
    filters = { "alpha", "alpha", "alpha" },
    sort_texts = { "same", "same", "same" },
    ids = { "id\255", "id\128", "id\255" },
    frecency_keys = { "accepted\255", "accepted\128", "accepted\255" },
    offsets = { 0, 0, 0 },
    deprecated = { false, false, false },
    regions = { 1, 1, 1 },
    filetypes = { "lua" },
  })
  local requests = { { snapshot = snapshot, query = "al", eligible = { true } } }
  local _, indexes, original_scores = yoz.completion.rank(requests, "")
  t.assert_true(vim.deep_equal({ 1, 2 }, indexes), "input ordering and first duplicate identity")
  local history = yoz.completion.new_history()
  history:access("lua\0accepted\255")
  local data = history:dump()
  for _, entry in pairs(data.items) do
    entry.timestamps = { os.time() + 60 }
  end
  history:load(data)
  local _, preferred, scores = yoz.completion.rank(requests, "", history)
  t.assert_true(vim.deep_equal({ 1, 2 }, preferred), "access and snapshot use the same opaque key")
  t.assert_eq(
    math.min(6, history:score("lua\0accepted\255")),
    scores[1] - original_scores[1],
    "history bonus is applied to the exact byte identity"
  )
  local restored = yoz.completion.new_history(history:dump())
  local _, repeated = yoz.completion.rank(requests, "", restored)
  t.assert_true(vim.deep_equal(preferred, repeated), "persisted history retains the byte key digest")
end)

t:test("missing sortText preserves provider order and remains distinct from explicit text", function()
  local context = runtime.context("")
  local items = {
    assert(Item.new(context, "fixture", { label = "beta" })),
    assert(Item.new(context, "fixture", { label = "alpha" })),
    assert(Item.new(context, "fixture", { label = "zeta", sortText = "0" })),
  }
  local ranked = Rank.filter(context, Rank.prepare(items))
  t.assert_true(vim.deep_equal({ items[1], items[2], items[3] }, ranked), "missing keys keep original order")
  items[1].raw.sortText = "2"
  items[2].raw.sortText = "1"
  ranked = Rank.filter(context, Rank.prepare(items))
  t.assert_true(vim.deep_equal({ items[3], items[2], items[1] }, ranked), "explicit keys order candidates")
end)

t:test("compound LSP filters outrank suffix snippets without losing provider alternatives", function()
  local Lsp = require("era.keystroke.cmp.source.lsp")
  local client = { id = 10, name = "fixture", offset_encoding = "utf-16" }
  for _, example in ipairs({
    { line = "div>ul>li", label = "div>ul>li" },
    { line = "div>ul>l", label = "div>ul>l" },
    { line = "div.中文>ul>li", label = "div.中文>ul>li" },
    { line = "div>ul>li", label = "nested list", filter = "div>ul>li" },
  }) do
    local context = runtime.context(example.line)
    local range = {
      start = { line = 0, character = 0 },
      ["end"] = { line = 0, character = vim.str_utfindex(example.line, "utf-16") },
    }
    local items = Lsp.response(context, client, {
      {
        label = example.label,
        filterText = example.filter,
        textEdit = { range = range, newText = "<ul><li></li></ul>" },
      },
      { label = "link", textEdit = { range = range, newText = '<link rel="stylesheet">' } },
    }).items
    local suffix = Item.new(context, "snippets", { label = "li", insertText = "<li>$0</li>", insertTextFormat = 2 })
    local ranked = Rank.filter(context, Rank.prepare({ items[1], items[2], suffix }))
    t.assert_eq(items[1], ranked[1], "the complete input outranks a suffix-only completion")
    t.assert_true(vim.list_contains(ranked, items[2]), "the provider's suffix alternative remains selectable")
    t.assert_true(vim.list_contains(ranked, suffix), "the local suffix snippet remains selectable")
  end
end)

t:test("wide LSP edits preserve namespace filtering and explicit filterText semantics", function()
  local Lsp = require("era.keystroke.cmp.source.lsp")
  local client = { id = 10, name = "fixture", offset_encoding = "utf-16" }
  for _, example in ipairs({
    { line = "obj.ba", label = "bar", text = "obj.bar" },
    { line = 'obj["da', label = "data-id", text = 'obj["data-id"]' },
    { line = "obj.ba", label = "obj.bar", filter = "bar", text = "obj.bar" },
    { line = "obj.ba", label = "bar", filter = vim.NIL, text = "obj.bar" },
  }) do
    local context = runtime.context(example.line)
    local raw = {
      label = example.label,
      filterText = example.filter,
      textEdit = {
        newText = example.text,
        range = { start = { line = 0, character = 0 }, ["end"] = { line = 0, character = #example.line } },
      },
    }
    local item = Lsp.response(context, client, { raw }).items[1]
    local ranked = Rank.filter(context, Rank.prepare({ item }))
    t.assert_eq(item, ranked[1], "a wider edit does not add an unrelated namespace to the query")
    t.assert_eq(raw.textEdit, item.raw.textEdit, "the provider's editing range is preserved")
  end
end)

t:test("proximity preserves literal byte matching around invalid UTF-8 in nearby buffer lines", function()
  local context = runtime.context("")
  local items = {
    assert(Item.new(context, "lsp", { label = "alpha" })),
    assert(Item.new(context, "lsp", { label = "alpine" })),
    assert(Item.new(context, "lsp", { label = "al�ine", filterText = "alpine" })),
  }
  local current = runtime.context("al")
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "al", "\255alpha\255al\255ine" })
  local groups = Rank.prepare(items)
  local expected = Reference.query(current, groups)
  local ranked = Rank.filter(current, groups)
  t.assert_eq(#expected, #ranked, "all candidates remain usable")
  for index, item in ipairs(ranked) do
    t.assert_eq(expected[index].item, item, "ordered identity")
    t.assert_eq(expected[index].score, item.score, "byte-exact proximity")
  end
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "" })
end)

t:test("proximity rejects oversized ranges before copying buffer text", function()
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "a", string.rep("x", 1024 * 1024) })
  local context = runtime.context("a")
  local groups = Rank.prepare({ assert(Item.new(context, "lsp", { label = "alpha" })) })
  local copied = 0
  local read = vim.api.nvim_buf_get_lines
  t:patch_table(vim.api, "nvim_buf_get_lines", function(...)
    local lines = read(...)
    for _, line in ipairs(lines) do
      copied = copied + #line
    end
    return lines
  end)
  t.assert_eq(1, #Rank.filter(context, groups), "matching continues without proximity")
  t.assert_eq(0, copied, "oversized nearby text was never read")
end)

t:test("nearby byte budget accounts for buffers without a final newline", function()
  local eol = vim.api.nvim_get_option_value("eol", { buf = 0 })
  local fixeol = vim.api.nvim_get_option_value("fixeol", { buf = 0 })
  t:defer(function()
    vim.api.nvim_set_option_value("eol", eol, { buf = 0 })
    vim.api.nvim_set_option_value("fixeol", fixeol, { buf = 0 })
  end)
  vim.api.nvim_set_option_value("fixeol", false, { buf = 0 })
  local size
  local rank = yoz.completion.rank
  t:patch_table(yoz.completion, "rank", function(requests, nearby, history)
    size = #nearby
    return rank(requests, nearby, history)
  end)
  for _, ending in ipairs({ true, false }) do
    vim.api.nvim_set_option_value("eol", ending, { buf = 0 })
    for _, length in ipairs({ 9998, 9999 }) do
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "a", string.rep("x", length) })
      local context = runtime.context("a")
      Rank.filter(context, Rank.prepare({ assert(Item.new(context, "lsp", { label = "alpha" })) }))
      t.assert_eq(length == 9998 and 10000 or 0, size, "exact byte budget")
    end
  end
end)

t:test("invalid UTF-8 queries exclude only their group and preserve valid query mappings", function()
  local context = runtime.context("\255")
  local invalid = assert(Item.new(context, "fixture", { label = "alpha" }))
  local valid = assert(Item.new(context, "fixture", { label = "alpine" }))
  valid.filter_start_col = 1
  local groups = Rank.prepare({ invalid, valid })
  local ranked = Rank.filter(runtime.context("\255al"), groups)
  t.assert_eq(1, #ranked, "invalid query does not enter the matcher")
  t.assert_eq(valid, ranked[1], "remaining group indexes still map to the original item")
  t.assert_eq(2, #Rank.filter(runtime.context("al"), groups), "both snapshots remain usable after valid input")
end)

t:test("bounded ranking returns the same top 200 as a full sort across scores and ties", function()
  local initial = runtime.context("")
  local items, labels = {}, {}
  for index = 1, 3000 do
    local label = string.format("completion_%04d", (index * 173) % 3001)
    local raw = { label = label, sortText = tostring(index % 41) }
    local item = assert(Item.new(initial, "fixture", raw))
    item.score_offset = index % 19 - 9
    items[#items + 1], labels[#labels + 1] = item, label
  end
  local groups = Rank.prepare(items)
  local matcher = yoz.completion.new(labels)
  for _, query in ipairs({ "", "c", "cmp", "compleiton" }) do
    local context = runtime.context(query)
    local indexes, scores = matcher:query(query)
    local expected = {}
    for position, index in ipairs(indexes) do
      expected[#expected + 1] =
        { item = items[index], score = scores[position] + items[index].score_offset, order = index }
    end
    table.sort(expected, function(a, b)
      if a.score ~= b.score then
        return a.score > b.score
      end
      local left, right = a.item.raw.sortText, b.item.raw.sortText
      return left < right or (left == right and a.order < b.order)
    end)
    local ranked = Rank.filter(context, groups)
    t.assert_eq(math.min(200, #expected), #ranked, query .. " result limit")
    for index, item in ipairs(ranked) do
      t.assert_eq(expected[index].item.id, item.id, query .. " rank " .. index)
    end
  end
end)

t:test("ranking rejects incompatible snapshots before applying the result limit", function()
  local context = runtime.context("foo")
  local items = {}
  for index = 1, 250 do
    local stale = vim.tbl_extend("force", context, { buffer_version = 10 })
    items[#items + 1] = assert(Item.new(stale, "fixture", { label = "foo" .. index }))
  end
  local valid = assert(Item.new(context, "fixture", { label = "foo_valid" }))
  items[#items + 1] = valid
  items[#items + 1] = valid
  local ranked = Rank.filter(context, Rank.prepare(items))
  t.assert_eq(1, #ranked, "stale and duplicate items excluded")
  t.assert_eq(valid.id, ranked[1].id, "valid candidate survives stale higher scores")
end)

t:test("native global ranking agrees with full sorting across metadata and context regions", function()
  local context = runtime.context("obj.")
  local groups = {}
  local history = yoz.completion.new_history()
  for source = 1, 3 do
    local items = {}
    for index = 1, 500 do
      local label = string.format("completion_%04d", (index * 173) % 501)
      local origin = index % 11 == 0 and vim.tbl_extend("force", context, { buffer_version = 9 }) or context
      local raw = {
        label = label,
        sortText = tostring(index % 41),
        filterText = index % 3 == 0 and "obj." .. label or label,
        deprecated = index % 7 == 0,
        tags = index % 13 == 0 and { 1 } or nil,
      }
      local item = assert(Item.new(origin, "fixture" .. source, raw))
      item.score_offset = index % 19 / 2 - 9
      item.filter_start_col = index % 3 == 0 and 0 or 4
      items[#items + 1] = item
      if index % 17 == 0 then
        history:access("lua\0" .. item.frecency_key)
      end
      if index % 37 == 0 then
        items[#items + 1] = item
      end
    end
    vim.list_extend(groups, Rank.prepare(items))
  end
  local persisted = history:dump()
  for _, entry in pairs(persisted.items) do
    for index in ipairs(entry.timestamps) do
      entry.timestamps[index] = os.time() + 60
    end
  end
  history:load(persisted)
  for _, query in ipairs({ "", "co", "compleiton", "completion_0" }) do
    local current = runtime.context("obj." .. query)
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { current.line, "completion_0001 completion_0037 completion_0200" })
    for _, enabled in ipairs({ false, true }) do
      local expected = Reference.query(current, groups, enabled and history or nil)
      local actual = Rank.filter(current, groups, enabled and history or nil)
      t.assert_eq(#expected, #actual, query .. " result count")
      for index, item in ipairs(actual) do
        t.assert_eq(expected[index].item, item, query .. " item " .. index)
        t.assert_eq(expected[index].score, item.score, query .. " score " .. index)
      end
    end
  end
end)

t:test("native ranking keeps first eligible matching duplicate and drops a changed filetype", function()
  local context = runtime.context("")
  local stale = vim.tbl_extend("force", context, { buffer_version = 1 })
  local first = assert(Item.new(stale, "fixture", { label = "foo", filterText = "foo", sortText = "0" }))
  local second = assert(Item.new(context, "fixture", { label = "foo", filterText = "bar", sortText = "1" }))
  local third = assert(Item.new(context, "fixture", { label = "foo", filterText = "foo", sortText = "2" }))
  local later = assert(Item.new(context, "fixture", { label = "foo", filterText = "foo", sortText = "3" }))
  later.score_offset = 100
  local groups = Rank.prepare({ first, second, third, later })
  local current = runtime.context("foo")
  local items = Rank.filter(current, groups)
  t.assert_eq(1, #items, "identity deduplication")
  t.assert_eq(third, items[1], "first valid matching candidate owns the identity")
  current.filetype = "python"
  t.assert_eq(0, #Rank.filter(current, groups), "old filetype namespace is ineligible")
end)

t:run()
