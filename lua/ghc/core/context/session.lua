local Observable = fml.collection.Observable
local context_filepath = fml.path.locate_session_filepath({ filename = "config.json" })

---@class ghc.core.context.session : fml.collection.Viewmodel
---@field public buftype_extra fml.types.collection.IObservable
---@field public caller_winnr fml.types.collection.IObservable
---@field public caller_bufnr fml.types.collection.IObservable
---@field public filemap_dirty fml.types.collection.IObservable
---@field public find_file_last_command fml.types.collection.IObservable
---@field public find_file_keyword fml.types.collection.IObservable
---@field public find_file_scope fml.types.collection.IObservable
---@field public find_recent_keyword fml.types.collection.IObservable
---@field public find_recent_scope fml.types.collection.IObservable
---@field public flight_copilot fml.types.collection.IObservable
---@field public replace_path fml.types.collection.IObservable
---@field public search_last_command fml.types.collection.IObservable
---@field public search_scope fml.types.collection.IObservable
local context = fml.collection.Viewmodel
  .new({
    name = "context:session",
    filepath = context_filepath,
  })
  :register("buftype_extra", Observable.from_value(nil), false, false)
  :register("caller_winnr", Observable.from_value(nil), false, false)
  :register("caller_bufnr", Observable.from_value(nil), false, false)
  :register("filemap_dirty", Observable.from_value(true), true, false)
  :register("find_file_scope", Observable.from_value("C"), true, false)
  :register("find_file_last_command", Observable.from_value(nil), false, false)
  :register("find_file_keyword", Observable.from_value(""), true, false)
  :register("find_recent_keyword", Observable.from_value(""), true, false)
  :register("find_recent_scope", Observable.from_value("C"), true, false)
  :register("flight_copilot", Observable.from_value(false), true, false)
  :register("replace_path", Observable.from_value(""), true, false)
  :register("search_last_command", Observable.from_value(nil), false, false)
  :register("search_scope", Observable.from_value("C"), true, false)

context:load()
context:auto_reload()

--Auto refresh statusline
fml.fn.watch_observables({
  context.buftype_extra,
  context.find_file_scope,
  context.find_recent_scope,
  context.flight_copilot,
  context.search_scope,
}, function()
  vim.cmd("redrawstatus")
end)

return context
