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

---@class kyokuya.replace.IReplaceViewLineMeta
---@field public filepath             ?string current line indicate the filepath
---@field public lnum                 ?integer current line indicate the filepath
---@field public key                  ?kyokuya.replace.IReplaceStateKey

---@class kyokuya.replace.IReplaceViewLineHighlights
---@field public cstart               integer
---@field public cend                 integer
---@field public hlname               string|nil
