local Observable = fml.collection.Observable

local find_file_pattern = Observable.from_value("")
local find_scope = Observable.from_value("C")

---@class ghc.context.session : fml.collection.Viewmodel
---@field public find_file_pattern          fml.types.collection.IObservable
---@field public find_scope                 fml.types.collection.IObservable
local M = require("ghc.context.session.mod")
  :register("find_file_pattern", find_file_pattern, true, true)
  :register("find_scope", find_scope, true, true)

--Auto refresh statusline
vim.schedule(function()
  fml.fn.watch_observables({
    find_scope,
  }, function()
    vim.schedule(function()
      vim.cmd("redrawstatus")
    end)
  end)
end)
