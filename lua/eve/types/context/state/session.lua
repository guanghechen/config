---@class t.eve.context.state.bookmark
---@field public pinned                 t.eve.collection.IObservable

---@class t.eve.context.state.find
---@field public flag_case_sensitive    t.eve.collection.IObservable
---@field public flag_gitignore         t.eve.collection.IObservable
---@field public flag_fuzzy             t.eve.collection.IObservable
---@field public flag_regex             t.eve.collection.IObservable
---@field public includes               t.eve.collection.IObservable
---@field public excludes               t.eve.collection.IObservable
---@field public keyword                t.eve.collection.IObservable
---@field public scope                  t.eve.collection.IObservable

---@class t.eve.context.state.flight
---@field public autoload               t.eve.collection.IObservable
---@field public autosave               t.eve.collection.IObservable
---@field public copilot                t.eve.collection.IObservable
---@field public devmode                t.eve.collection.IObservable

---@class t.eve.context.state.search
---@field public flag_case_sensitive    t.eve.collection.IObservable
---@field public flag_gitignore         t.eve.collection.IObservable
---@field public flag_regex             t.eve.collection.IObservable
---@field public flag_replace           t.eve.collection.IObservable
---@field public max_filesize           t.eve.collection.IObservable
---@field public max_matches            t.eve.collection.IObservable
---@field public includes               t.eve.collection.IObservable
---@field public excludes               t.eve.collection.IObservable
---@field public keyword                t.eve.collection.IObservable
---@field public replacement            t.eve.collection.IObservable
---@field public scope                  t.eve.collection.IObservable
---@field public search_paths           t.eve.collection.IObservable

---@class t.eve.context.session.state
---@field public bookmark               t.eve.context.state.bookmark
---@field public find                   t.eve.context.state.find
---@field public flight                 t.eve.context.state.flight
---@field public search                 t.eve.context.state.search

---@class t.eve.context.session
---@field public state                  t.eve.context.session.state
---@field public defaults               fun(): t.eve.context.session.data
---@field public dump                   fun(): t.eve.context.session.data
---@field public load                   fun(data: t.eve.context.session.data): nil
---@field public normalize              fun(data: any): t.eve.context.session.data
