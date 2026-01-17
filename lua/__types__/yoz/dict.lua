---@meta

---@module 'yoz.dict'
---@class yoz.dict
local dict = {}

---@class yoz.dict.ISearchResult
---@field public type                   'scalar'|'segment'
---@field public indexes                integer[]

---@class yoz.dict.ISearchOptions
---@field public keyword                string
---@field public language               ?string
---@field public match_mode             ?'prefix'|'substring'
---@field public include_compounds      ?boolean
---@field public max_items              ?integer

---@param options                       yoz.dict.ISearchOptions|string
---@return yoz.dict.ISearchResult[]
function dict.search(options) end

return dict
