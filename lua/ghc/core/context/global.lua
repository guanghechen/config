local Observable = require("guanghechen.observable.Observable")
local Viewmodel = require("guanghechen.viewmodel.Viewmodel")
local path = require("ghc.core.util.path")
local util_observable = require("guanghechen.util.observable")

---@class ghc.core.context.global: guanghechen.viewmodel.Viewmodel
---@field public darken guanghechen.observable.Observable
---@field public theme_lighten guanghechen.observable.Observable
---@field public theme_darken guanghechen.observable.Observable
local context = Viewmodel
  .new({
    name = "global",
    filepath = path.gen_local_config_filepath({ filename = "context/global.json" }),
  })
  --
  :register("darken", Observable.new(true), true)
  :register("theme_lighten", Observable.new("one_light"), true)
  :register("theme_darken", Observable.new("onedark"), true)

context:load()

--Auto refresh statusline
util_observable.watch_observables({
  context.darken,
  context.theme_lighten,
  context.theme_darken,
}, function()
  vim.cmd("redrawstatus")
end)

--Auto save
util_observable.watch_observables({
  context.darken,
  context.theme_lighten,
  context.theme_darken,
}, function()
  context:save()
end)

return context
