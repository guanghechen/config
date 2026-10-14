---@meta

---@diagnostic disable-next-line: unused-local
local __module_name__ = "yoz.completion" ---@type string

---@class yoz.completion.Matcher
local Matcher = {}

---@param query                         string
---@return integer[] indexes
---@return integer[] scores
function Matcher:query(query) end

--- Native-endian records: uint32 one-based index followed by int32 score.
---@param query                         string
---@return string
function Matcher:query_packed(query) end

---@class yoz.completion.Snapshot

---@class yoz.completion.ISnapshotData
---@field public labels                 string[]
---@field public filters                string[]
---@field public sort_texts             (string|false)[] False preserves a missing sortText without an array hole.
---@field public ids                    string[] Opaque bytes for identity and deduplication.
---@field public frecency_keys          string[] Opaque bytes, hashed with the filetype namespace.
---@field public offsets                number[]
---@field public deprecated             boolean[]
---@field public regions                integer[] One-based region ID for each candidate.
---@field public filetypes              string[] Filetype for each region.

---@class yoz.completion.IRankRequest
---@field public snapshot               yoz.completion.Snapshot
---@field public query                  string
---@field public eligible               boolean[]

---@class yoz.completion.IHistoryData
---@field public MAX_TIMESTAMPS         ?integer
---@field public items                  table<string, { timestamps: integer[], idx: integer }>

---@class yoz.completion.History
local History = {}

---@param key                           string
---@return nil
function History:access(key) end

---@param key                           string
---@return number
function History:score(key) end

---@return yoz.completion.IHistoryData
function History:dump() end

---@param data                          yoz.completion.IHistoryData
---@return nil
function History:load(data) end

---@class yoz.completion
local M = {}

---@param labels                        string[]
---@return yoz.completion.Matcher
function M.new(labels) end

---@param data                          yoz.completion.ISnapshotData
---@return yoz.completion.Snapshot
function M.new_snapshot(data) end

---@param data                          ?yoz.completion.IHistoryData
---@return yoz.completion.History
function M.new_history(data) end

--- Zero-based, end-exclusive UTF-8 byte ranges for matched label characters.
---@param query                         string
---@param text                          string
---@return integer[][]
function M.match_ranges(query, text) end

---@param requests                      yoz.completion.IRankRequest[]
---@param nearby                        string
---@param history                       ?yoz.completion.History
---@return integer[] groups
---@return integer[] indexes
---@return number[] scores
function M.rank(requests, nearby, history) end

return M
