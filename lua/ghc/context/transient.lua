local Observable = fml.collection.Observable
local Viewmodel = fml.collection.Viewmodel

---@class ghc.context.transient : fml.collection.Viewmodel
---@field public search_last_command    fml.types.collection.IObservable
local context = Viewmodel.new({ name = "context:transient" })

return context
