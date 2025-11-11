---@meta

---@module 'rstd.dict'
---@class rstd.dict
local dict = {}

---@class rstd.dict.ISearchResult
---@field type                          'scalar'|'segment'
---@field indexes                       integer[]

---@class rstd.dict.ISearchOptions
---@field keyword                       string
---@field language                      string?
---@field match_mode                    'prefix'|'substring'?
---@field include_compounds             boolean?
---@field max_items                     integer?

---@param options                       rstd.dict.ISearchOptions|string
---@return rstd.dict.ISearchResult[]
function dict.search(options) end

return dict
