---@meta

---@module 'rstd.dict'
---@class rstd.dict
local dict = {}

---@class rstd.dict.ISearchResult
---@field public type                   'scalar'|'segment'
---@field public indexes                integer[]

---@class rstd.dict.ISearchOptions
---@field public keyword                string
---@field public language               string|nil
---@field public match_mode             'prefix'|'substring'|nil
---@field public include_compounds      boolean|nil
---@field public max_items              integer|nil

---@param options                       rstd.dict.ISearchOptions|string
---@return rstd.dict.ISearchResult[]
function dict.search(options) end

return dict
