local Observable = fml.collection.Observable

local flight_autoload_session = Observable.from_value(false)
local flight_copilot = Observable.from_value(false)

---@class ghc.context.session : fml.collection.Viewmodel
---@field public flight_autoload_session    fml.types.collection.IObservable
---@field public flight_copilot             fml.types.collection.IObservable
local M = require("ghc.context.session.mod")
  :register("flight_autoload_session", flight_autoload_session, true, true)
  :register("flight_copilot", flight_copilot, true, true)

--Auto refresh statusline
vim.schedule(function()
  fml.fn.watch_observables({
    flight_copilot,
  }, function()
    vim.schedule(function()
      vim.cmd("redrawstatus")
    end)
  end)
end)
