local Observable = require("guanghechen.observable.Observable")
local Viewmodel = require("guanghechen.viewmodel.Viewmodel")
local util_observable = require("guanghechen.util.observable")
local globals = require("ghc.core.setting.globals")

local config_dir = vim.fn.stdpath("config")
local context_config_filepath = config_dir
  .. globals.path_sep
  .. "config"
  .. globals.path_sep
  .. "local"
  .. globals.path_sep
  .. "context"
  .. globals.path_sep
  .. "config.json"

---@class ghc.core.context.config: guanghechen.viewmodel.Viewmodel
---@field public darken guanghechen.observable.Observable
---@field public relativenumber guanghechen.observable.Observable
---@field public theme_lighten guanghechen.observable.Observable
---@field public theme_darken guanghechen.observable.Observable
---@field public transparency guanghechen.observable.Observable
---@field public get_current_theme fun():string
local context = Viewmodel.new({ name = "config", filepath = context_config_filepath })
  :register("context_config_filepath", Observable.new(context_config_filepath), true)
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
