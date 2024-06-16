---@class guanghechen.types.IReplaceOptions
---@field public cwd string
---@field public flag_regex boolean
---@field public flag_case_sensitive boolean
---@field public replace_patterh string
---@field public search_patterh string
---@field public search_paths string
---@field public include_patterns string[]
---@field public exclude_patterns string[]

---@class guanghechen.types.IReplaceInlineMatchedItem
---@field public front integer
---@field public tail integer
---@field public replace string

---@class guanghechen.types.IReplaceLineMatchedItem
---@field public lines string
---@field public line_start integer
---@field public matches guanghechen.types.IReplaceInlineMatchedItem[]

---@class guanghechen.types.IReplaceFileMatchedItem
---@field public filepath string
---@field public matches guanghechen.types.IReplaceLineMatchedItem[]

---@class guanghechen.types.IReplaceResult
---@field public elapsed_time string
---@field public items? guanghechen.types.IReplaceFileMatchedItem[]
---@field public error? string

---@class guanghechen.types.IReplaceState
---@field public cwd string
---@field public flag_regex boolean
---@field public flag_case_sensitive boolean
---@field public replace_patterh string
---@field public search_patterh string
---@field public search_paths string
---@field public include_patterns string[]
---@field public exclude_patterns string[]
