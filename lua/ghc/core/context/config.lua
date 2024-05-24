local guanghechen = require("guanghechen")
local Observable = require("guanghechen.observable.Observable")
local Viewmodel = require("guanghechen.viewmodel.Viewmodel")

local context_config_filepath = guanghechen.util.path.locate_context_filepath("config.json")

---@class ghc.core.context.config: guanghechen.viewmodel.Viewmodel
---@field public darken guanghechen.observable.Observable
---@field public relativenumber guanghechen.observable.Observable
---@field public theme_lighten guanghechen.observable.Observable
---@field public theme_darken guanghechen.observable.Observable
---@field public transparency guanghechen.observable.Observable
---@field public get_current_theme fun():string
local context = Viewmodel.new({
  name = "context:config",
  filepath = context_config_filepath,
})
  :register("darken", Observable.new(true), true)
  :register("relativenumber", Observable.new(true), true)
  :register("theme_lighten", Observable.new("one_light"), true)
  :register("theme_darken", Observable.new("onedark"), true)
  :register("transparency", Observable.new(false), true)

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
guanghechen.util.observable.watch_observables({
  context.darken,
  context.theme_lighten,
  context.theme_darken,
  context.transparency,
}, function()
  vim.cmd("redrawstatus")
end)

return context
