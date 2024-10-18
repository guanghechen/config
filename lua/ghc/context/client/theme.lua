---@class ghc.context.client
---@field public theme                  eve.types.collection.IObservable
---@field public transparency           eve.types.collection.IObservable
local M = require("ghc.context.client.mod")
  ---
  :register("theme", eve.c.Observable.from_value("darken"), true, true)
  :register("transparency", eve.c.Observable.from_value(false), true, true)

---Auto refresh statusline
vim.schedule(function()
  eve.mvc.observe({
    M.theme,
    M.transparency,
  }, function()
    vim.cmd.redrawstatus()
  end, true)
end)
