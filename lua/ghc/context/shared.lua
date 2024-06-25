local Observable = fml.collection.Observable
local Viewmodel = fml.collection.Viewmodel

local context_filepath = fml.path.locate_context_filepath({ filename = "shared.json" })

---@class ghc.context.shared : fml.collection.Viewmodel
---@field public relativenumber fml.types.collection.IObservable
local context = Viewmodel.new({
  name = "context:shared",
  filepath = context_filepath,
})
  :register("relativenumber", Observable.from_value(true), true, true)

context:load()
context:auto_reload()

return context
