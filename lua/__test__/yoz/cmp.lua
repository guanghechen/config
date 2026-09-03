---@diagnostic disable: undefined-global

local harness = require("__test__.harness")

local t = harness.new("yoz.cmp")
local native = require("yoz")

t:test("keyword range preserves UTF-8 boundaries", function()
  local line = "你好-world"
  local start_col, end_col = native.cmp.keyword_range(line, #"你好-w", true)
  t.assert_eq(0, start_col, "start column")
  t.assert_eq(#line, end_col, "end column")
end)

t:test("matched ranges project strict ASCII and Unicode subsequences", function()
  local ranges = native.cmp.matched_ranges("cmp", { "Completion", "other" })
  t.assert_true(vim.deep_equal({ 0, 1, 2, 4 }, ranges[1]), "ASCII byte ranges")
  t.assert_true(vim.deep_equal({}, ranges[2]), "unmatched label")

  ranges = native.cmp.matched_ranges("你界", { "你好世界" })
  t.assert_true(vim.deep_equal({ 0, 3, 9, 12 }, ranges[1]), "Unicode byte ranges")

  ranges = native.cmp.matched_ranges("äb", { "ÄpfelBeta" })
  t.assert_true(vim.deep_equal({ 0, 2, 6, 7 }, ranges[1]), "case-insensitive byte ranges")
end)

t:test("fuzzy match orders prefixes and score offsets", function()
  local results = native.cmp.fuzzy_match("cmp", {
    { text = "create_map", score_offset = 0 },
    { text = "completion", score_offset = 0 },
    { text = "cmp", score_offset = 20 },
  })

  t.assert_eq(3, #results, "result count")
  t.assert_eq(3, results[1].index, "exact item")
  t.assert_true(results[1].exact, "exact prefix")
  t.assert_eq(2, results[2].index, "prefix item")
end)

t:test("fuzzy match rejects missing subsequences", function()
  local results = native.cmp.fuzzy_match("xyz", {
    { text = "example" },
  })
  t.assert_eq(0, #results, "unmatched items")
end)

t:test("fuzzy match recalls one typo without changing top-k semantics", function()
  local texts = { "print", "printf", "println", "paint", "priority_queue" }
  local index = native.cmp.index(texts, 0, nil, true)
  local results = index:rank("pritn", nil, 10000000, 200)
  t.assert_eq(1, results[1], "transposed exact candidate")
  t.assert_true(vim.list_contains(results, 2), "related typo candidate")

  local items = vim
    .iter(texts)
    :map(function(text)
      return { text = text }
    end)
    :totable()
  results = native.cmp.matcher(items):match("pritn", nil, 10000000, 200)
  t.assert_eq(1, results[1].index, "matcher typo candidate")
  results = native.cmp.fuzzy_match("pritn", items, 10000000, 200)
  t.assert_eq(1, results[1].index, "table matcher typo candidate")
  results = native.cmp.rank("pritn", texts, 0, nil, true, nil, 10000000, 200)
  t.assert_eq(1, results[1].index, "flat rank typo candidate")

  local top_k = native.cmp.index({ "p_r_i_t_n", "print" }, 0, nil, true)
  local full = top_k:rank("pritn", nil, 10000000, 200)
  local top = top_k:rank("pritn", nil, 10000000, 1)
  t.assert_eq(full[1], top[1], "top-k consistency")
  t.assert_eq(2, top[1], "best typo candidate")

  local dense = {}
  for index = 1, 32 do
    dense[index] = string.format("p_r_i_t_n_%02d", index)
  end
  dense[33] = "print"
  results = native.cmp.index(dense, 0, nil, true):rank("pritn", nil, 10000000, 200)
  t.assert_eq(33, results[1], "dense strict results preserve typo recall")

  local prefixed = native.cmp.index({ "pritn_value", "print" }, 0, nil, true)
  results = prefixed:rank("pritn", nil, 10000000, 200)
  t.assert_eq(2, #results, "strict prefix keeps typo repair")
  t.assert_eq(1, results[1], "strict prefix")
  t.assert_eq(2, results[2], "competing typo repair")
end)

t:test("fuzzy match supports two prefix typos for longer queries", function()
  local texts = { "completion", "compile", "computation" }
  local query = "complxtjon"
  local index = native.cmp.index(texts, 0, nil, true)
  local results = index:rank(query, nil, 10000000, 200)
  t.assert_eq(1, results[1], "index two-typo candidate")

  local items = vim
    .iter(texts)
    :map(function(text)
      return { text = text }
    end)
    :totable()
  results = native.cmp.matcher(items):match(query, nil, 10000000, 200)
  t.assert_eq(1, results[1].index, "matcher two-typo candidate")
  results = native.cmp.fuzzy_match(query, items, 10000000, 200)
  t.assert_eq(1, results[1].index, "table matcher two-typo candidate")
  results = native.cmp.rank(query, texts, 0, nil, true, nil, 10000000, 200)
  t.assert_eq(1, results[1].index, "flat rank two-typo candidate")

  results = native.cmp.index({ "abcdefgh" }, 0, nil, true):rank("xycdefgh", nil, 10000000, 200)
  t.assert_eq(1, results[1], "two substitutions absent from the candidate mask")

  results = native.cmp.index({ "baacbaa" }, 0, nil, true):rank("baabacaa", nil, 10000000, 200)
  t.assert_eq(1, results[1], "deletion followed by transposition")

  results = native.cmp.index({ "abcdefg" }, 0, nil, true):rank("abcxefy", nil, 10000000, 200)
  t.assert_eq(0, #results, "short query remains one-typo bounded")
end)

t:test("fuzzy match limits ranked output after matching", function()
  local items = {} ---@type yoz.cmp.IMatchItem[]
  for index = 1, 600 do
    items[index] = { text = string.format("item-%03d", index) }
  end
  local results = native.cmp.fuzzy_match("item", items, nil, 5)
  t.assert_eq(5, #results, "limited results")
end)

t:test("cached matcher reuses candidates and applies current usage", function()
  local matcher = native.cmp.matcher({
    { text = "alpha", usage_key = "source\0alpha" },
    { text = "alphabet", usage_key = "source\0alphabet" },
  })
  local initial = matcher:match("alpha", nil, 10000000)
  t.assert_eq(1, initial[1].index, "initial exact item")

  local recent = matcher:match("alpha", {
    ["source\0alphabet"] = { count = 12, last_used = 10000000 },
  }, 10000000)
  t.assert_eq(2, recent[1].index, "current usage")
end)

t:test("native usage index updates cached matchers without rebuilding", function()
  local matcher = native.cmp.matcher({
    { text = "alpha", usage_key = "source\0alpha" },
    { text = "alphabet", usage_key = "source\0alphabet" },
  })
  local usage = native.cmp.usage({})
  usage:set("source\0alphabet", { count = 12, last_used = 10000000 })
  local results = matcher:match("alpha", usage, 10000000)
  t.assert_eq(2, results[1].index, "updated usage")
end)

t:test("native usage records continuous decay and prunes stale entries", function()
  local now = 10000000
  local usage = native.cmp.usage({
    legacy = { count = 2, last_used = now },
    stale = { score = 1, last_used = now - 90 * 24 * 60 * 60 },
  })

  usage:record("legacy", now)
  local updated = usage:snapshot(now)
  t.assert_true(math.abs(updated.legacy.score - 3) < 0.0001, "legacy migration")
  local snapshot = usage:snapshot(now + 7 * 24 * 60 * 60)
  t.assert_true(math.abs(snapshot.legacy.score - 1.5) < 0.001, "half-life decay")
  t.assert_nil(snapshot.stale, "stale pruning")
  local reloaded = native.cmp.usage(snapshot):snapshot(now + 7 * 24 * 60 * 60)
  t.assert_true(math.abs(reloaded.legacy.score - 1.5) < 0.001, "persisted score reload")
end)

t:test("word ranking applies sparse usage before its limit", function()
  local items = {} ---@type yoz.cmp.IMatchItem[]
  for index = 1, 500 do
    local word = string.format("target%03d", index)
    items[index] = { text = word, usage_key = word }
  end
  items[#items + 1] = { text = "aatarget", usage_key = "aatarget" }
  local results = native.cmp.matcher(items):match("target", {
    aatarget = { count = 12, last_used = 10000000 },
  }, 10000000, 500)
  t.assert_eq(500, #results, "result count")
  t.assert_eq(501, results[1].index, "recent item")
end)

t:test("frecency favors recent usage and decays old usage", function()
  local now = 10000000
  local results = native.cmp.fuzzy_match("alpha", {
    { text = "alpha", use_count = 2, last_used = now - 60 },
    { text = "alpha", use_count = 64, last_used = now - 90 * 24 * 60 * 60 },
  }, now)
  t.assert_eq(1, results[1].index, "recent item")
end)

t:test("flat ranking preserves offsets and usage without item tables", function()
  local results = native.cmp.rank(
    "alpha",
    { "alpha", "alphabet" },
    { 0, 10 },
    {
      "source\0alpha",
      "source\0alphabet",
    },
    nil,
    {
      ["source\0alphabet"] = { count = 12, last_used = 10000000 },
    },
    10000000
  )
  t.assert_eq(2, results[1].index, "offset and usage")
end)

t:test("flat ranking applies sort text before its limit without usage keys", function()
  local results = native.cmp.rank("item", { "item1", "item2", "item3" }, { 0, 0, 0 }, nil, {
    "3",
    "2",
    "1",
  }, nil, 10000000, 2)
  t.assert_eq(2, #results, "result count")
  t.assert_eq(3, results[1].index, "first sort text")
  t.assert_eq(2, results[2].index, "second sort text")
end)

t:test("flat ranking reuses texts as sort keys", function()
  local results = native.cmp.rank("item", { "item3", "item1", "item2" }, 0, nil, true)
  t.assert_eq(2, results[1].index, "first text")
  t.assert_eq(3, results[2].index, "second text")
  t.assert_eq(1, results[3].index, "third text")
end)

t:test("flat ranking accepts sparse usage keys", function()
  local results = native.cmp.rank(
    "alpha",
    { "alpha", "alphabet" },
    0,
    {
      [2] = "used",
    },
    true,
    {
      used = { count = 12, last_used = 10000000 },
    },
    10000000
  )
  t.assert_eq(2, results[1].index, "sparse usage item")
end)

t:test("immutable index reuses projections and returns flat indices", function()
  local index = native.cmp.index(
    { "alpha", "alphabet", "alphanumeric" },
    { 0, 10, 0 },
    { [2] = "used" },
    { "3", "2", "1" }
  )
  local results = index:rank("alpha", {
    used = { count = 12, last_used = 10000000 },
  }, 10000000, 2)

  t.assert_eq(2, #results, "result count")
  t.assert_eq("number", type(results[1]), "flat result")
  t.assert_eq(2, results[1], "usage and score offset")
end)

t:test("immutable index applies a nearby-word bonus without rebuilding", function()
  local index = native.cmp.index({ "alphaOne", "alphaTwo" }, 0, nil, { "a", "z" }, { "alphaOne", "alphaTwo" })

  local ordinary = index:rank("alpha", nil, 10000000, 200)
  local nearby = index:rank("alpha", nil, 10000000, 200, { "alphaTwo" })

  t.assert_eq(1, ordinary[1], "sort text without proximity")
  t.assert_eq(2, nearby[1], "nearby candidate")
end)

t:test("immutable index can reuse match text as sort text", function()
  local index = native.cmp.index({ "item3", "item1", "item2" }, 0, nil, true)
  local results = index:rank("item", nil, nil, 3)

  t.assert_eq(2, results[1], "first text")
  t.assert_eq(3, results[2], "second text")
  t.assert_eq(1, results[3], "third text")
end)

t:test("word extraction keeps Unicode identifiers", function()
  local words = native.cmp.words("hello 你好世界 hello completion_item caféValue", 10)
  t.assert_eq(4, #words, "word count")
  t.assert_eq("你好世界", words[2], "Unicode word")
  t.assert_eq("caféValue", words[4], "decomposed word")
end)

t:test("cached fuzzy matching stays within the popup latency budget at scale", function()
  local ascii = {} ---@type yoz.cmp.IMatchItem[]
  for index = 1, 50000 do
    ascii[index] = {
      text = string.format("candidate_value_%05d", index),
      score_offset = 100,
      usage_key = "buffer\0" .. index,
    }
  end
  local ascii_matcher = native.cmp.matcher(ascii)
  local started = vim.uv.hrtime()
  local ascii_results = ascii_matcher:match("cdvl42", nil, 10000000, 200)
  local ascii_ms = (vim.uv.hrtime() - started) / 1000000

  local usage = native.cmp.usage({})
  for index = 1, 1000 do
    usage:record("buffer\0" .. index, 10000000)
  end
  started = vim.uv.hrtime()
  local usage_results = ascii_matcher:match("cdvl42", usage, 10000000, 200)
  local usage_ms = (vim.uv.hrtime() - started) / 1000000

  local unicode = {} ---@type yoz.cmp.IMatchItem[]
  for index = 1, 10000 do
    unicode[index] = { text = "候选candidate值" .. index, score_offset = 100 }
  end
  local unicode_matcher = native.cmp.matcher(unicode)
  started = vim.uv.hrtime()
  local unicode_results = unicode_matcher:match("候c值", nil, 10000000, 200)
  local unicode_ms = (vim.uv.hrtime() - started) / 1000000

  print(
    string.format("BENCH cmp fuzzy ascii50k=%.3fms usage1k=%.3fms unicode10k=%.3fms", ascii_ms, usage_ms, unicode_ms)
  )
  t.assert_eq(200, #ascii_results, "ASCII result limit")
  t.assert_eq(200, #usage_results, "usage result limit")
  t.assert_eq(200, #unicode_results, "Unicode result limit")
  t.assert_true(ascii_ms < 10, string.format("ASCII matching %.3fms", ascii_ms))
  t.assert_true(usage_ms < 12, string.format("usage matching %.3fms", usage_ms))
  t.assert_true(unicode_ms < 10, string.format("Unicode matching %.3fms", unicode_ms))
end)

t:test("bounded typo fallback stays within the popup latency budget at scale", function()
  local hits = {} ---@type string[]
  local misses = {} ---@type string[]
  local double_ascii = {} ---@type string[]
  local double_unicode = {} ---@type string[]
  local long_ascii = {} ---@type string[]
  local long_unicode = {} ---@type string[]
  for index = 1, 10000 do
    hits[index] = string.format("print_%05d", index)
    misses[index] = string.format("zzzzz_%05d", index)
    double_unicode[index] = string.format("你好世界和平未来_candidate_%05d", index)
    long_unicode[index] =
      string.format("__你一二三四五六七八九十甲乙丙丁戊己庚辛壬癸世界_%05d", index)
  end
  local gapped_ascii = "__a_b_c_d_e_f_g_h_i_j_k_l_m_n_o_p_q_r_s_t_u_v_w_x"
  for index = 1, 50000 do
    double_ascii[index] = string.format("internationalization_candidate_%05d", index)
    long_ascii[index] = string.format("%s_candidate_%05d", gapped_ascii, index)
  end
  local hit_index = native.cmp.index(hits, 0, nil, true)
  local miss_index = native.cmp.index(misses, 0, nil, true)
  local double_ascii_index = native.cmp.index(double_ascii, 0, nil, true)
  local double_unicode_index = native.cmp.index(double_unicode, 0, nil, true)
  local long_ascii_index = native.cmp.index(long_ascii, 0, nil, true)
  local long_unicode_index = native.cmp.index(long_unicode, 0, nil, true)

  local started = vim.uv.hrtime()
  local hit_results = hit_index:rank("pritn", nil, 10000000, 200)
  local hit_ms = (vim.uv.hrtime() - started) / 1000000
  started = vim.uv.hrtime()
  local miss_results = miss_index:rank("pritn", nil, 10000000, 200)
  local miss_ms = (vim.uv.hrtime() - started) / 1000000
  started = vim.uv.hrtime()
  local double_ascii_results = double_ascii_index:rank("interxatyonalization", nil, 10000000, 200)
  local double_ascii_ms = (vim.uv.hrtime() - started) / 1000000
  started = vim.uv.hrtime()
  local double_unicode_results = double_unicode_index:rank("你坏世界和战未来", nil, 10000000, 200)
  local double_unicode_ms = (vim.uv.hrtime() - started) / 1000000
  started = vim.uv.hrtime()
  local long_ascii_results = long_ascii_index:rank("abcdefghijklmnopqrstuvxw", nil, 10000000, 200)
  local long_ascii_ms = (vim.uv.hrtime() - started) / 1000000
  started = vim.uv.hrtime()
  local long_unicode_results =
    long_unicode_index:rank("你一二三四五六七八九十甲乙丙丁戊己庚辛壬癸界世", nil, 10000000, 200)
  local long_unicode_ms = (vim.uv.hrtime() - started) / 1000000

  print(
    string.format(
      "BENCH cmp typo hit10k=%.3fms miss10k=%.3fms double_ascii50k=%.3fms double_unicode10k=%.3fms nonprefix_ascii50k=%.3fms nonprefix_unicode10k=%.3fms",
      hit_ms,
      miss_ms,
      double_ascii_ms,
      double_unicode_ms,
      long_ascii_ms,
      long_unicode_ms
    )
  )
  t.assert_eq(200, #hit_results, "typo hit result limit")
  t.assert_eq(0, #miss_results, "typo miss result count")
  t.assert_eq(200, #double_ascii_results, "two-typo ASCII result limit")
  t.assert_eq(200, #double_unicode_results, "two-typo Unicode result limit")
  t.assert_eq(200, #long_ascii_results, "non-prefix ASCII typo result limit")
  t.assert_eq(200, #long_unicode_results, "non-prefix Unicode typo result limit")
  t.assert_true(hit_ms < 10, string.format("typo hit matching %.3fms", hit_ms))
  t.assert_true(miss_ms < 10, string.format("typo miss matching %.3fms", miss_ms))
  t.assert_true(double_ascii_ms < 15, string.format("two-typo ASCII matching %.3fms", double_ascii_ms))
  t.assert_true(double_unicode_ms < 15, string.format("two-typo Unicode matching %.3fms", double_unicode_ms))
  t.assert_true(long_ascii_ms < 15, string.format("non-prefix ASCII typo matching %.3fms", long_ascii_ms))
  t.assert_true(long_unicode_ms < 15, string.format("non-prefix Unicode typo matching %.3fms", long_unicode_ms))
end)

t:run()
