local Observable = fml.collection.Observable
local Viewmodel = fml.collection.Viewmodel

local context_filepath = fml.path.locate_session_filepath({ filename = "session.json" })

---@class ghc.context.session : fml.collection.Viewmodel
---@field public buftype_extra fml.types.collection.IObservable
---@field public filemap_dirty fml.types.collection.IObservable
---@field public find_file_last_command fml.types.collection.IObservable
---@field public search_last_command fml.types.collection.IObservable
local context = Viewmodel
  .new({ name = "context:session", filepath = context_filepath })
  :register("buftype_extra", Observable.from_value(nil), false, false)
  :register("filemap_dirty", Observable.from_value(true), true, false)
  :register("find_file_last_command", Observable.from_value(nil), false, false)
  :register("search_last_command", Observable.from_value(nil), false, false)

context:load()
--context:auto_reload()

--Auto refresh statusline
fml.fn.watch_observables({
  context.buftype_extra,
}, function()
  vim.cmd("redrawstatus")
end)

return context
