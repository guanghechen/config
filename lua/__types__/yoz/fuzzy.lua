---@meta

---@diagnostic disable-next-line: unused-local
local __module_name__ = "yoz.fuzzy" ---@type string

---fzf-style matching (fzf v0.74.5 algorithms and extended syntax) over a corpus kept on the native side.
---@class yoz.fuzzy
local M = {}

---@alias yoz.fuzzy.Scheme
---|"default" # fzf's default scheme: bonuses after whitespace and `/,:;|`; ties prefer shorter items.
---|"path"    # fzf's path scheme: bonuses after `/`; ties prefer matches in the basename.

---@alias yoz.fuzzy.CaseMode
---|"smart"   # Case-sensitive only for terms with an uppercase character.
---|"respect"
---|"ignore"

---@class yoz.fuzzy.ICorpusOptions
---@field public scheme                 ?yoz.fuzzy.Scheme Defaults to "default".

---@class yoz.fuzzy.IQuery
---@field public pattern                string Extended syntax: space-separated terms, `'`, `^`, `$`, `!`, `|`; `\ ` is a literal space.
---@field public fuzzy                  ?boolean False makes plain terms exact substrings. Defaults to true.
---@field public case                   ?yoz.fuzzy.CaseMode Defaults to "smart".
---@field public rank                   ?boolean False only decides membership and keeps item order. Defaults to true.
---@field public weight                 ?integer Points added for an item weight of 100. Defaults to 0.

---@param options                       ?yoz.fuzzy.ICorpusOptions
---@return yoz.fuzzy.Corpus
function M.new_corpus(options) end

---@class yoz.fuzzy.Corpus
local Corpus = {}

---Appends items with their Treeview keys: the item's node key, or an array of it followed by keys of
---nodes shown with it. Invalid UTF-8 is replaced.
---@param texts                         string[]
---@param keys                          (string|string[])[]
---@return nil
function Corpus:append(texts, keys) end

---One byte per item, 0..100, such as frecency.
---@param weights                       string
---@return nil
function Corpus:set_weights(weights) end

---@param query                         yoz.fuzzy.IQuery
---@return yoz.fuzzy.Result
function Corpus:query(query) end

---@class yoz.fuzzy.Result
local Result = {}

---@return integer
function Result:count() end

---First keys of the matches in rank order, a 1-based inclusive range defaulting to every match.
---@param first                         ?integer
---@param last                          ?integer
---@return string[]
function Result:keys(first, last) end

---Whether both results come from one corpus with the same matches in the same order.
---@param other                         yoz.fuzzy.Result
---@return boolean
function Result:same(other) end

---Whether the item whose first key is `key` matched.
---@param key                           string
---@return boolean
function Result:has(key) end

---Matched byte ranges of the item whose first key is `key`, 0-based and end-exclusive, merged into runs;
---nil when it did not match.
---@param key                           string
---@return yoz.search.ISearchInLinesMatchPoint[]|nil
function Result:highlight(key) end

---Node ids of the matches in rank order, each item's keys in order, for a display filter.
---@param source                        yoz.ux.treeview.Source
---@return yoz.ux.treeview.NodeIds
function Result:ids(source) end
