local Observable = fml.collection.Observable

---@class ghc.context.client
---@field public relativenumber         fml.types.collection.IObservable
local M = require("ghc.context.client.mod")
  ---
  :register("relativenumber", Observable.from_value(true), true, true)
