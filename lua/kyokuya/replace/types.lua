---@class kyokuya.types.ISearchMatchedInlineItem
---@field public front integer
---@field public tail integer

---@class kyokuya.types.ISearchMatchedLineItem
---@field public lines string
---@field public lnum integer
---@field public matches kyokuya.types.ISearchMatchedInlineItem[]

---@class kyokuya.types.ISearchMatchedFileItem
---@field public matches kyokuya.types.ISearchMatchedLineItem[]

---@class kyokuya.types.ISearchResult
---@field public elapsed_time string
---@field public items? table<string, kyokuya.types.ISearchMatchedFileItem>
---@field public error? string

---@class kyokuya.types.ISearcherState
---@field public cwd string
---@field public flag_regex boolean
---@field public flag_case_sensitive boolean
---@field public search_pattern string
---@field public search_paths string[]
---@field public include_patterns string[]
---@field public exclude_patterns string[]

---@class kyokuya.types.ISearcherOptions
---@field public state? kyokuya.types.ISearcherState|nil
---@field public force? boolean

---@class kyokuya.types.ISearcher
---@field public search fun(self, opts: kyokuya.types.ISearcherOptions|nil): kyokuya.types.ISearchResult|nil
---@field public replace_preview fun(self, text: string, replace_pattern: string): string

---@class kyokuya.types.IOXISearchOptions
---@field public cwd string
---@field public flag_regex boolean
---@field public flag_case_sensitive boolean
---@field public search_pattern string
---@field public search_paths string[]
---@field public include_patterns string[]
---@field public exclude_patterns string[]

---@class kyokuya.types.IReplacerOptions
---@field public state? kyokuya.types.IReplacerState|nil
---@field public winnr? integer
---@field public force? boolean

---@alias kyokuya.types.IReplaceMode
---| "replace"
---| "search"

---@class kyokuya.types.IReplacerState : kyokuya.types.ISearcherState
---@field public mode kyokuya.types.IReplaceMode
---@field public replace_pattern string

---@alias kyokuya.types.IReplaceStateKey
---|"cwd"
---|"mode"
---|"flag_regex"
---|"flag_case_sensitive"
---|"search_pattern"
---|"replace_pattern"
---|"search_paths"
---|"include_patterns"
---|"exclude_patterns"

---@class kyokuya.types.IReplaceResultLineMeta
---@field public filepath? string current line indicate the filepath
---@field public lnum? integer current line indicate the filepath
---@field public key? kyokuya.types.IReplaceStateKey  current line pointer to a replacer-state field
