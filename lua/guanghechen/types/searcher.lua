---@class guanghechen.types.ISearchMatchedInlineItem
---@field public front integer
---@field public tail integer

---@class guanghechen.types.ISearchMatchedLineItem
---@field public lines string
---@field public lineno integer
---@field public matches guanghechen.types.ISearchMatchedInlineItem[]

---@class guanghechen.types.ISearchMatchedFileItem
---@field public filepath string
---@field public matches guanghechen.types.ISearchMatchedLineItem[]

---@class guanghechen.types.ISearchResult
---@field public elapsed_time string
---@field public items? guanghechen.types.ISearchMatchedFileItem[]
---@field public error? string

---@class guanghechen.types.ISearcherState
---@field public cwd string
---@field public flag_regex boolean
---@field public flag_case_sensitive boolean
---@field public search_pattern string
---@field public search_paths string[]
---@field public include_patterns string[]
---@field public exclude_patterns string[]

---@class guanghechen.types.ISearcherOptions
---@field public state? guanghechen.types.ISearcherState|nil
---@field public force? boolean

---@class guanghechen.types.ISearcher
---@field public get_state fun(self): guanghechen.types.ISearcherState|nil
---@field public set_state fun(self, next_state: guanghechen.types.ISearcherState|nil): nil
---@field public search fun(self, opts?: guanghechen.types.ISearcherOptions|nil): guanghechen.types.ISearchResult|nil
---@field public replace_preview fun(self, text: string, replace_pattern: string): string

---@class guanghechen.types.IOXISearchOptions
---@field public cwd string
---@field public flag_regex boolean
---@field public flag_case_sensitive boolean
---@field public search_pattern string
---@field public search_paths string[]
---@field public include_patterns string[]
---@field public exclude_patterns string[]
