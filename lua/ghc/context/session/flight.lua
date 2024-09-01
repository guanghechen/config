local flight_autoload_session = fc.c.Observable.from_value(false)
local flight_copilot = fc.c.Observable.from_value(false)

---@class ghc.context.session : fc.collection.Viewmodel
---@field public flight_autoload_session    fc.types.collection.IObservable
---@field public flight_copilot             fc.types.collection.IObservable
local M = require("ghc.context.session.mod")
  :register("flight_autoload_session", flight_autoload_session, true, true)
  :register("flight_copilot", flight_copilot, true, true)

--Auto refresh statusline
vim.schedule(function()
  fml.fn.watch_observables({
    flight_copilot,
  }, function()
    vim.cmd("redrawstatus")
  end)
end)
