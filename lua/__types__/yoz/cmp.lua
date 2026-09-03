---@meta

---@class yoz.cmp.IMatchItem
---@field public text                   string
---@field public score_offset           integer|nil
---@field public usage_score            number|nil
---@field public use_count              integer|nil
---@field public last_used              integer|nil
---@field public usage_key              string|nil
---@field public proximity_key          string|nil

---@class yoz.cmp.IMatchResult
---@field public index                  integer
---@field public score                  integer
---@field public exact                  boolean

---@class yoz.cmp
local M = {}

---@class yoz.cmp.IMatcher
local Matcher = {}

---@class yoz.cmp.IIndex
local Index = {}

---@class yoz.cmp.IUsage
local Usage = {}

---@class yoz.cmp.IUsageRecord
---@field public score                  number
---@field public last_used              integer

---@param key                           string
---@param value                         integer|{ count: integer, last_used: integer }|yoz.cmp.IUsageRecord
function Usage:set(key, value) end

---@param key                           string
---@param now                           integer|nil Unix timestamp
function Usage:record(key, now) end

---@param now                           integer|nil Unix timestamp
---@return table<string, yoz.cmp.IUsageRecord>
function Usage:snapshot(now) end

---@param query                         string
---@param usage                         yoz.cmp.IUsage|table<string, integer|{ count: integer, last_used: integer }|yoz.cmp.IUsageRecord>|nil
---@param now                           integer|nil Unix timestamp
---@param limit                         integer|nil
---@return yoz.cmp.IMatchResult[]
function Matcher:match(query, usage, now, limit) end

---@param query                         string
---@param usage                         yoz.cmp.IUsage|table<string, integer|{ count: integer, last_used: integer }|yoz.cmp.IUsageRecord>|nil
---@param now                           integer|nil Unix timestamp
---@param limit                         integer|nil
---@param nearby_words                  string[]|nil
---@return integer[] ranked stable indices
function Index:rank(query, usage, now, limit, nearby_words) end

---@param line                          string
---@param cursor_col                    integer 0-indexed byte column
---@param include_suffix                boolean|nil
---@return integer start_col 0-indexed byte column
---@return integer end_col 0-indexed byte column
function M.keyword_range(line, cursor_col, include_suffix) end

---@param query                         string
---@param labels                        string[]
---@return integer[][] label-relative 0-indexed byte range pairs
function M.matched_ranges(query, labels) end

---@param items                         yoz.cmp.IMatchItem[]
---@return yoz.cmp.IMatcher
function M.matcher(items) end

---@param texts                         string[]
---@param score_offsets                 integer|integer[]|nil
---@param usage_keys                    (string|nil)[]|nil
---@param sort_texts                    string[]|true|nil `true` reuses `texts` as sort keys
---@param proximity_keys                string[]|nil labels used by the optional nearby-word bonus
---@return yoz.cmp.IIndex
function M.index(texts, score_offsets, usage_keys, sort_texts, proximity_keys) end

---@param values                        table<string, integer|{ count: integer, last_used: integer }|yoz.cmp.IUsageRecord>
---@return yoz.cmp.IUsage
function M.usage(values) end

---@param query                         string
---@param items                         yoz.cmp.IMatchItem[]
---@param now                           integer|nil Unix timestamp
---@param limit                         integer|nil
---@return yoz.cmp.IMatchResult[]
function M.fuzzy_match(query, items, now, limit) end

---@param query                         string
---@param texts                         string[]
---@param score_offsets                 integer|integer[]|nil
---@param usage_keys                    (string|nil)[]|nil
---@param sort_texts                    string[]|true|nil `true` reuses `texts` as sort keys
---@param usage                         yoz.cmp.IUsage|table<string, integer|{ count: integer, last_used: integer }|yoz.cmp.IUsageRecord>|nil
---@param now                           integer|nil Unix timestamp
---@param limit                         integer|nil
---@return yoz.cmp.IMatchResult[]
function M.rank(query, texts, score_offsets, usage_keys, sort_texts, usage, now, limit) end

---@param value                         string
---@param limit                         integer|nil
---@return string[]
function M.words(value, limit) end

return M
