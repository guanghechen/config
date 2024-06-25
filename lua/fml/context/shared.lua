local Observable = require("fml.collection.observable")
local Viewmodel = require("fml.collection.viewmodel")
local watch_observables = require("fml.fn.watch_observables")
local path = require("fml.core.path")
local context_filepath = path.locate_context_filepath({ filename = "shared.json" })

---@class fml.context.shared: fml.collection.Viewmodel
---@field public relativenumber fml.types.collection.IObservable
local context = Viewmodel.new({
  name = "context:shared",
  filepath = context_filepath,
})
  :register("relativenumber", Observable.from_value(true), true, true)

context:load()
context:auto_reload()

return context
