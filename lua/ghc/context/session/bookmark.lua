local pinned_filepaths = eve.c.Observable.from_value({})

---@class ghc.context.session : eve.collection.Viewmodel
---@field public pinned_filepaths       eve.types.collection.IObservable
local M = require("ghc.context.session.mod") --
  :register("pinned_filepaths", pinned_filepaths, true, false)

return M
