---@class t.eve.context.data.bookmark
---@field public pinned                 string[]

---@class t.eve.context.data.find
---@field public flag_case_sensitive    boolean
---@field public flag_gitignore         boolean
---@field public flag_fuzzy             boolean
---@field public flag_regex             boolean
---@field public includes               string[]
---@field public excludes               string[]
---@field public keyword                string
---@field public scope                  t.eve.e.FindScope

---@class t.eve.context.data.flight
---@field public autoload               boolean
---@field public autosave               boolean
---@field public copilot                boolean
---@field public devmode                boolean

---@class t.eve.context.data.search
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
---@field public scope                  t.eve.e.SearchScope
---@field public search_paths           string[]

---@class t.eve.context.session.data
---@field public bookmark               t.eve.context.data.bookmark
---@field public find                   t.eve.context.data.find
---@field public flight                 t.eve.context.data.flight
---@field public search                 t.eve.context.data.search
