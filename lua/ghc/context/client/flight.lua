local flight_devmode = eve.c.Observable.from_value(false)

---@class ghc.context.client : eve.collection.Viewmodel
---@field public flight_devmode         eve.types.collection.IObservable
local M = require("ghc.context.client.mod") --
  :register("flight_devmode", flight_devmode, true, true)

--Auto refresh statusline
vim.schedule(function()
  eve.mvc.observe({
    flight_devmode,
  }, function()
    vim.cmd.redrawstatus()
  end, true)
end)
