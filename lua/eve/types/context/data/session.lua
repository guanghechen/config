---@class eve.t.context.data.bookmark
---@field public pinned                 string[]

---@class eve.t.context.data.find
---@field public flag_case_sensitive    boolean
---@field public flag_gitignore         boolean
---@field public flag_fuzzy             boolean
---@field public flag_regex             boolean
---@field public includes               string[]
---@field public excludes               string[]
---@field public keyword                string
---@field public scope                  eve.e.FindScope

---@class eve.t.context.data.flight
---@field public autoload               boolean
---@field public autosave               boolean
---@field public copilot                boolean
---@field public devmode                boolean
---@field public lsp_inlay_hints        boolean

---@class eve.t.context.data.search
---@field public flag_case_sensitive    boolean
---@field public flag_gitignore         boolean
---@field public flag_regex             boolean
---@field public flag_replace           boolean
---@field public max_filesize           string
---@field public max_matches            integer
---@field public includes               string[]
---@field public excludes               string[]
---@field public keyword                string
---@field public replacement            string
---@field public scope                  eve.e.SearchScope
---@field public search_paths           string[]

---@class eve.t.context.session.data
---@field public bookmark               eve.t.context.data.bookmark
---@field public find                   eve.t.context.data.find
---@field public flight                 eve.t.context.data.flight
---@field public search                 eve.t.context.data.search
