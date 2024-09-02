local flight_autoload_session = eve.c.Observable.from_value(false)
local flight_copilot = eve.c.Observable.from_value(false)

---@class ghc.context.session : eve.collection.Viewmodel
---@field public flight_autoload_session    eve.types.collection.IObservable
---@field public flight_copilot             eve.types.collection.IObservable
local M = require("ghc.context.session.mod")
  :register("flight_autoload_session", flight_autoload_session, true, false)
  :register("flight_copilot", flight_copilot, true, false)

--Auto refresh statusline
vim.schedule(function()
  fml.fn.watch_observables({
    flight_copilot,
  }, function()
    vim.cmd("redrawstatus")
  end)
end)
