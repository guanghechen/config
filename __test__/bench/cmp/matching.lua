---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.bench.cmp.matching" ---@type string

local Data = require("__test__.bench.cmp.data")
local M = {}

---@param indexes                       integer[]
---@param labels                        string[]
---@param zero_based                    ?boolean
---@return string[]
local function selected_labels(indexes, labels, zero_based)
  local result = {}
  for _, index in ipairs(indexes) do
    result[#result + 1] = labels[index + (zero_based and 1 or 0)]
  end
  return result
end

---@param left                          string[]
---@param right                         string[]
---@return table
local function agreement(left, right)
  local seen, common, left_only, right_only = {}, 0, {}, {}
  for _, label in ipairs(left) do
    seen[label] = true
  end
  for _, label in ipairs(right) do
    if seen[label] then
      common = common + 1
      seen[label] = nil
    else
      right_only[#right_only + 1] = label
    end
  end
  for label in pairs(seen) do
    left_only[#left_only + 1] = label
  end
  table.sort(left_only)
  table.sort(right_only)
  return {
    era_count = #left,
    blink_count = #right,
    intersection = common,
    jaccard = #left + #right == 0 and 1 or common / (#left + #right - common),
    era_only_examples = vim.list_slice(left_only, 1, 5),
    blink_only_examples = vim.list_slice(right_only, 1, 5),
  }
end

---@param options                       table
---@return table
function M.run(options)
  local Runtime = require("__test__.fixtures.era.keystroke.cmp.runtime")
  Runtime.setup(options.baseline)
  local Rank = require("era.keystroke.cmp.rank")
  local Item = require("era.keystroke.cmp.item")
  local native = yoz.completion
  local blink = require("blink.cmp.fuzzy.rust")
  local config = require("blink.cmp.config")
  config.fuzzy.frecency.enabled = false
  config.fuzzy.use_proximity = true
  config.fuzzy.sorts = { "score", "exact", "sort_text" }
  config.fuzzy.max_typos = function(query)
    return math.min(2, math.floor(vim.str_utfindex(query, "utf-32") / 4))
  end
  local fuzzy = require("blink.cmp.fuzzy")
  local shared_typos = config.fuzzy.max_typos

  ---@param query                       string
  ---@return integer
  local function default_typos(query)
    return math.floor(#query / 4)
  end
  fuzzy.set_implementation("rust")
  local result = {
    construction = {},
    queries = {},
    quality = {},
    note = "timings in ms; candidate sets and typo budget shared, scoring algorithms differ",
  }
  local corpora = {}
  for _, count in ipairs({ 1000, 10000, 50000 }) do
    corpora[#corpora + 1] = {
      name = "identifiers",
      labels = Data.labels(count),
      queries = { "", "c", "get", "gcu", "getCompletion", "compleiton", "zzzzqqqq", "变量" },
    }
    corpora[#corpora + 1] = { name = "dense_typo", labels = Data.labels(count, true), queries = { "compleiton" } }
  end
  local api_labels = {}
  for name in pairs(vim.api) do
    api_labels[#api_labels + 1] = name
  end
  table.sort(api_labels)
  corpora[#corpora + 1] = {
    name = "neovim_api",
    labels = api_labels,
    queries = { "nvim_", "nbgl", "nvim_buf_get_lnes", "nvim_win_set_cursor" },
  }

  for _, corpus in ipairs(corpora) do
    local labels = corpus.labels
    local raw = Data.items(labels)
    local context = Runtime.context("")
    local items = {}
    for index, item in ipairs(raw) do
      items[index] = assert(Item.new(context, "bench", item))
    end
    local matcher, groups
    local construction = Data.measure({
      era_native = function()
        matcher = native.new(labels)
      end,
      era_prepare = function()
        groups = Rank.prepare(items)
      end,
      blink_native = function()
        blink.set_provider_items("bench", raw)
      end,
    }, options.samples)
    result.construction[#result.construction + 1] = {
      corpus = corpus.name,
      candidates = #labels,
      timings = construction,
      sha256 = vim.fn.sha256(table.concat(labels, "\n")),
    }
    fuzzy.haystacks_by_provider_cache.bench = raw
    local providers = { bench = raw }
    for _, query in ipairs(corpus.queries) do
      context = Runtime.context(query)
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { query })
      local settings = {
        max_typos = config.fuzzy.max_typos(query),
        use_frecency = false,
        use_proximity = false,
        match_suffix = false,
        snippet_score_offset = 0,
      }
      local timings = Data.measure({
        era_native = function()
          return matcher:query(query)
        end,
        era_native_packed = function()
          return matcher:query_packed(query)
        end,
        blink_native = function()
          local _, indexes = blink.fuzzy(query, #query, { "bench" }, settings)
          return indexes
        end,
        era_rank = function()
          return Rank.filter(context, groups)
        end,
        blink_rank = function()
          return require("blink.cmp.lib.utils").slice(fuzzy.fuzzy(query, #query, providers, "prefix"), 1, 200)
        end,
        blink_rank_default_typos = function()
          config.fuzzy.max_typos = default_typos
          local filtered = fuzzy.fuzzy(query, #query, providers, "prefix")
          config.fuzzy.max_typos = shared_typos
          return require("blink.cmp.lib.utils").slice(filtered, 1, 200)
        end,
      }, options.samples)
      local own = matcher:query(query)
      local _, theirs = blink.fuzzy(query, #query, { "bench" }, settings)
      local compare = agreement(selected_labels(own, labels), selected_labels(theirs, labels, true))
      local own_top, blink_top = {}, {}
      for _, item in ipairs(Rank.filter(context, groups)) do
        own_top[#own_top + 1] = item.raw.label
      end
      for index, item in ipairs(fuzzy.fuzzy(query, #query, providers, "prefix")) do
        if index > 10 then
          break
        end
        blink_top[#blink_top + 1] = item.label
      end
      result.queries[#result.queries + 1] = {
        corpus = corpus.name,
        candidates = #labels,
        query = query,
        timings = timings,
        agreement = compare,
        era_top10 = vim.list_slice(own_top, 1, 10),
        blink_top10 = blink_top,
      }
    end
  end

  local quality_labels = {
    "completion",
    "complete",
    "CompletionItem",
    "getCurrentUser",
    "getClientUrl",
    "getconfigurationurl",
    "get_current_user",
    "nvim_buf_get_lines",
    "nvim_buf_set_lines",
    "nvim_get_current_buf",
    "workspaceSymbols",
    "writeTextFile",
    "readTextFile",
    "foo",
    "fooBar",
    "xfoo",
    "fOtherOotherO",
    "中文变量",
    "变量名称",
    "éclair",
    "Écriture",
    "parseHTTPResponse",
    "print",
  }
  local matcher = native.new(quality_labels)
  blink.set_provider_items("quality", Data.items(quality_labels))
  for _, query in ipairs({
    "foo",
    "gcu",
    "GCU",
    "compleiton",
    "complextion",
    "completiom",
    "nbgl",
    "nvim_buf_get_lnes",
    "中变",
    "变量",
    "écl",
    "ecl",
    "HTTP",
    "zzzzqqqq",
    "commplettioon",
  }) do
    local own, scores = matcher:query(query)
    local _, theirs = blink.fuzzy(
      query,
      #query,
      { "quality" },
      { max_typos = config.fuzzy.max_typos(query), sorts = { "score", "exact", "sort_text" } }
    )
    local scored = {}
    for index, candidate in ipairs(own) do
      scored[#scored + 1] = { index = candidate, score = scores[index] }
    end
    table.sort(scored, function(a, b)
      return a.score > b.score or (a.score == b.score and quality_labels[a.index] < quality_labels[b.index])
    end)
    own = {}
    for _, value in ipairs(scored) do
      own[#own + 1] = value.index
    end
    local ours = selected_labels(own, quality_labels)
    local theirs_labels = selected_labels(theirs, quality_labels, true)
    local _, default_indexes = blink.fuzzy(query, #query, { "quality" }, {
      max_typos = default_typos(query),
      sorts = { "score", "exact", "sort_text" },
    })
    result.quality[#result.quality + 1] = {
      query = query,
      era = ours,
      blink = theirs_labels,
      agreement = agreement(ours, theirs_labels),
      blink_default_typos = selected_labels(default_indexes, quality_labels, true),
    }
  end
  return result
end

return M
