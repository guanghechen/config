local Observable = fml.collection.Observable
local Viewmodel = fml.collection.Viewmodel

local buftype_extra = Observable.from_value(nil)
local filemap_dirty = Observable.from_value(true)
local find_file_last_command = Observable.from_value(nil)
local search_last_command = Observable.from_value(nil)

---@class ghc.context.transient : fml.collection.Viewmodel
---@field public buftype_extra          fml.types.collection.IObservable
---@field public filemap_dirty          fml.types.collection.IObservable
---@field public find_file_last_command fml.types.collection.IObservable
---@field public search_last_command    fml.types.collection.IObservable
local context = Viewmodel
    .new({ name = "context:transient" })
    :register("buftype_extra", buftype_extra, false, false)
    :register("filemap_dirty", filemap_dirty, false, false)
    :register("find_file_last_command", find_file_last_command, false, false)
    :register("search_last_command", search_last_command, false, false)

--Auto refresh statusline
fml.fn.watch_observables({
  context.buftype_extra,
}, function()
  vim.cmd("redrawstatus")
end)

return context
