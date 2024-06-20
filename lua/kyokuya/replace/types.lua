---@alias kyokuya.replace.IReplaceMode
---| "replace"
---| "search"

---@alias kyokuya.replace.IReplaceStateKey
---|"cwd"
---|"mode"
---|"flag_regex"
---|"flag_case_sensitive"
---|"search_pattern"
---|"replace_pattern"
---|"search_paths"
---|"include_patterns"
---|"exclude_patterns"

---@class kyokuya.replace.IReplaceStateData
---@field public cwd                  string
---@field public mode                 kyokuya.replace.IReplaceMode
---@field public flag_regex           boolean
---@field public flag_case_sensitive  boolean
---@field public search_pattern       string
---@field public replace_pattern      string
---@field public search_paths         string
---@field public include_patterns     string
---@field public exclude_patterns     string

---@class kyokuya.replace.ISearchMatchedInlineItem
---@field public l                integer
---@field public r                 integer

---@class kyokuya.replace.ISearchMatchedLineItem
---@field public text                string
---@field public lnum                 integer
---@field public matches              kyokuya.replace.ISearchMatchedInlineItem[]

---@class kyokuya.replace.ISearchMatchedFileItem
---@field public matches              kyokuya.replace.ISearchMatchedLineItem[]

---@class kyokuya.replace.ISearchResult
---@field public elapsed_time         string
---@field public items                ?table<string, kyokuya.replace.ISearchMatchedFileItem>
---@field public error                ? string

---@class kyokuya.replace.IOXISearchOptions
---@field public cwd                  string
---@field public flag_regex           boolean
---@field public flag_case_sensitive  boolean
---@field public search_pattern       string
---@field public search_paths         string
---@field public include_patterns     string
---@field public exclude_patterns     string

---@class kyokuya.replace.IReplaceViewLineMeta
---@field public filepath             ?string current line indicate the filepath
---@field public lnum                 ?integer current line indicate the filepath
---@field public key                  ?kyokuya.replace.IReplaceStateKey

---@class kyokluya.replace.IReplaceViewLineHighlights
---@field public cstart               integer
---@field public cend                 integer
---@field public hlname               string|nil
