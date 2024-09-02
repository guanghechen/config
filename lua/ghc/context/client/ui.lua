---@class ghc.context.client
---@field public relativenumber         eve.types.collection.IObservable
local M = require("ghc.context.client.mod")
  ---
  :register("relativenumber", eve.c.Observable.from_value(true), true, true)
