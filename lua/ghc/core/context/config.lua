local Observable = fml.collection.Observable
local Viewmodel = require("guanghechen.viewmodel.Viewmodel")
local util_observable = require("guanghechen.util.observable")

local context_config_filepath = fml.path.locate_context_filepath("config.json")

---@class ghc.core.context.config: guanghechen.viewmodel.Viewmodel
---@field public darken fml.types.collection.IObservable
---@field public relativenumber fml.types.collection.IObservable
---@field public theme_lighten fml.types.collection.IObservable
---@field public theme_darken fml.types.collection.IObservable
---@field public transparency fml.types.collection.IObservable
---@field public get_current_theme fun():string
local context = Viewmodel.new({
  name = "context:config",
  filepath = context_config_filepath,
})
  :register("darken", Observable.from_value(true), true, true)
  :register("relativenumber", Observable.from_value(true), true, true)
  :register("theme_lighten", Observable.from_value("one_light"), true, true)
  :register("theme_darken", Observable.from_value("onedark"), true, true)
  :register("transparency", Observable.from_value(false), true, true)

---@return string
function context.get_current_theme()
  ---@type boolean
  local is_darken = context.darken:get_snapshot()

  ---@type string
  local theme_lighten = context.theme_lighten:get_snapshot()

  ---@type string
  local theme_darken = context.theme_darken:get_snapshot()

  return is_darken and theme_darken or theme_lighten
end

context:load()
context:auto_reload()

--Auto refresh statusline
util_observable.watch_observables({
  context.darken,
  context.theme_lighten,
  context.theme_darken,
  context.transparency,
}, function()
  vim.cmd("redrawstatus")
end)

return context
