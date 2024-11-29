---@class eve.t.context.state.bookmark
---@field public pinned                 eve.t.collection.IObservable

---@class eve.t.context.state.find
---@field public flag_case_sensitive    eve.t.collection.IObservable
---@field public flag_gitignore         eve.t.collection.IObservable
---@field public flag_fuzzy             eve.t.collection.IObservable
---@field public flag_regex             eve.t.collection.IObservable
---@field public includes               eve.t.collection.IObservable
---@field public excludes               eve.t.collection.IObservable
---@field public keyword                eve.t.collection.IObservable
---@field public scope                  eve.t.collection.IObservable

---@class eve.t.context.state.flight
---@field public autoload               eve.t.collection.IObservable
---@field public autosave               eve.t.collection.IObservable
---@field public copilot                eve.t.collection.IObservable
---@field public devmode                eve.t.collection.IObservable
---@field public lsp_inlay_hints        eve.t.collection.IObservable

---@class eve.t.context.state.search
---@field public flag_case_sensitive    eve.t.collection.IObservable
---@field public flag_gitignore         eve.t.collection.IObservable
---@field public flag_regex             eve.t.collection.IObservable
---@field public flag_replace           eve.t.collection.IObservable
---@field public max_filesize           eve.t.collection.IObservable
---@field public max_matches            eve.t.collection.IObservable
---@field public includes               eve.t.collection.IObservable
---@field public excludes               eve.t.collection.IObservable
---@field public keyword                eve.t.collection.IObservable
---@field public replacement            eve.t.collection.IObservable
---@field public scope                  eve.t.collection.IObservable
---@field public search_paths           eve.t.collection.IObservable

---@class eve.t.context.session.state
---@field public bookmark               eve.t.context.state.bookmark
---@field public find                   eve.t.context.state.find
---@field public flight                 eve.t.context.state.flight
---@field public search                 eve.t.context.state.search

---@class eve.t.context.session
---@field public state                  eve.t.context.session.state
---@field public defaults               fun(): eve.t.context.session.data
---@field public dump                   fun(): eve.t.context.session.data
---@field public load                   fun(data: eve.t.context.session.data): nil
---@field public normalize              fun(data: any): eve.t.context.session.data
