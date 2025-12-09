---@meta

---@module 'yoz.dict'
---@class yoz.dict
local dict = {}

---@class yoz.dict.ISearchResult
---@field public type                   'scalar'|'segment'
---@field public indexes                integer[]

---@class yoz.dict.ISearchOptions
---@field public keyword                string
---@field public language               string|nil
---@field public match_mode             'prefix'|'substring'|nil
---@field public include_compounds      boolean|nil
---@field public max_items              integer|nil

---@param options                       yoz.dict.ISearchOptions|string
---@return yoz.dict.ISearchResult[]
function dict.search(options) end

return dict
