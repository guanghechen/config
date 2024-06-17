---@class guanghechen.types.IReplaceInlineMatchedItem
---@field public front integer
---@field public tail integer
---@field public replace string

---@class guanghechen.types.IReplaceLineMatchedItem
---@field public lines string
---@field public lineno integer
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
---@field public replace_pattern string
---@field public search_pattern string
---@field public search_paths string[]
---@field public include_patterns string[]
---@field public exclude_patterns string[]

---@class guanghechen.types.IReplaceOptions
---@field public force? boolean

---@class guanghechen.types.IReplacer
---@field public replace fun(self, opts?: guanghechen.types.IReplaceOptions): guanghechen.types.IReplaceResult
---@field public equals fun(self, next_state: guanghechen.types.IReplaceState): boolean
---@field public get_state fun(self): guanghechen.types.IReplaceState
---@field public set_state fun(self, next_state: guanghechen.types.IReplaceState|nil): guanghechen.types.IReplaceState
