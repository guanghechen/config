---@class eve.t.state.data.bookmark
---@field public pinned                 string[]

---@class eve.t.state.state.bookmark
---@field public pinned                 eve.lib.collection.IObservable

---@class eve.t.state.data.dressing
---@field public hi_pairs               boolean
---@field public winsep_fixed           boolean
---@field public winsep_float           boolean

---@class eve.t.state.state.dressing
---@field public hi_pairs               eve.lib.collection.IObservable
---@field public winsep_fixed           eve.lib.collection.IObservable
---@field public winsep_float           eve.lib.collection.IObservable

---@class eve.t.state.data.find
---@field public flag_case_sensitive    boolean
---@field public flag_gitignore         boolean
---@field public flag_fuzzy             boolean
---@field public flag_regex             boolean
---@field public includes               string[]
---@field public excludes               string[]
---@field public keyword                string
---@field public scope                  eve.e.FindScope

---@class eve.t.state.state.find
---@field public flag_case_sensitive    eve.lib.collection.IObservable
---@field public flag_gitignore         eve.lib.collection.IObservable
---@field public flag_fuzzy             eve.lib.collection.IObservable
---@field public flag_regex             eve.lib.collection.IObservable
---@field public includes               eve.lib.collection.IObservable
---@field public excludes               eve.lib.collection.IObservable
---@field public keyword                eve.lib.collection.IObservable
---@field public scope                  eve.lib.collection.IObservable

---@class eve.t.state.data.flight
---@field public autoload               boolean
---@field public autosave               boolean
---@field public copilot                boolean
---@field public devmode                boolean
---@field public lsp_inlay_hints        boolean
---@field public lsp_code_lens          boolean

---@class eve.t.state.state.flight
---@field public autoload               eve.lib.collection.IObservable
---@field public autosave               eve.lib.collection.IObservable
---@field public copilot                eve.lib.collection.IObservable
---@field public devmode                eve.lib.collection.IObservable
---@field public lsp_inlay_hints        eve.lib.collection.IObservable
---@field public lsp_code_lens          eve.lib.collection.IObservable

---@class eve.t.state.data.frecency
---@field public files                  eve.lib.collection.frecency.ISerializedData

---@class eve.t.state.state.frecency
---@field public files                  eve.lib.collection.IFrecency

---@class eve.t.state.data.input_history
---@field public find_files             eve.lib.collection.history.ISerializedData
---@field public search_in_files        eve.lib.collection.history.ISerializedData

---@class eve.t.state.state.input_history
---@field public find_files             eve.lib.collection.IHistory
---@field public search_in_files        eve.lib.collection.IHistory

---@class eve.t.state.data.search
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

---@class eve.t.state.state.search
---@field public flag_case_sensitive    eve.lib.collection.IObservable
---@field public flag_gitignore         eve.lib.collection.IObservable
---@field public flag_regex             eve.lib.collection.IObservable
---@field public flag_replace           eve.lib.collection.IObservable
---@field public max_filesize           eve.lib.collection.IObservable
---@field public max_matches            eve.lib.collection.IObservable
---@field public includes               eve.lib.collection.IObservable
---@field public excludes               eve.lib.collection.IObservable
---@field public keyword                eve.lib.collection.IObservable
---@field public replacement            eve.lib.collection.IObservable
---@field public scope                  eve.lib.collection.IObservable
---@field public search_paths           eve.lib.collection.IObservable

---@class eve.t.state.workspace.data
---@field public bookmark               eve.t.state.data.bookmark
---@field public dressing               eve.t.state.data.dressing
---@field public find                   eve.t.state.data.find
---@field public flight                 eve.t.state.data.flight
---@field public frecency               eve.t.state.data.frecency
---@field public input_history          eve.t.state.data.input_history
---@field public search                 eve.t.state.data.search

---@class eve.t.state.workspace.state
---@field public bookmark               eve.t.state.state.bookmark
---@field public dressing               eve.t.state.state.dressing
---@field public find                   eve.t.state.state.find
---@field public flight                 eve.t.state.state.flight
---@field public frecency               eve.t.state.state.frecency
---@field public input_history          eve.t.state.state.input_history
---@field public search                 eve.t.state.state.search

---@class eve.t.state.workspace
---@field public state                  eve.t.state.workspace.state
---@field public defaults               fun(): eve.t.state.workspace.data
---@field public dump                   fun(): eve.t.state.workspace.data
---@field public load                   fun(data: eve.t.state.workspace.data): nil
---@field public normalize              fun(data: any): eve.t.state.workspace.data
