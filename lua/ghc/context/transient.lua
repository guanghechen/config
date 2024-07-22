local Observable = fml.collection.Observable
local Viewmodel = fml.collection.Viewmodel

local filemap_dirty = Observable.from_value(true)
local find_file_last_command = Observable.from_value(nil)
local search_last_command = Observable.from_value(nil)

---@class ghc.context.transient : fml.collection.Viewmodel
---@field public filemap_dirty          fml.types.collection.IObservable
---@field public find_file_last_command fml.types.collection.IObservable
---@field public search_last_command    fml.types.collection.IObservable
local context = Viewmodel.new({ name = "context:transient" })
  :register("filemap_dirty", filemap_dirty, false, false)
  :register("find_file_last_command", find_file_last_command, false, false)
  :register("search_last_command", search_last_command, false, false)

return context
