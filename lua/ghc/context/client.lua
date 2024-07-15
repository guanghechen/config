local theme = require("ghc.ui.theme")
local Observable = fml.collection.Observable
local Viewmodel = fml.collection.Viewmodel

local context_filepath = fml.path.locate_context_filepath({ filename = "client.json" }) ---@type string
local theme_cache_path = fml.path.locate_context_filepath({ filename = "theme" }) ---@type string

---@class ghc.context.client : ghc.types.context.client
---@field public mode                   fml.types.collection.IObservable
---@field public relativenumber         fml.types.collection.IObservable
---@field public transparency           fml.types.collection.IObservable
local context = Viewmodel.new({ name = "context:client", filepath = context_filepath, verbose = true })
  :register("mode", Observable.from_value("darken"), true, true)
  :register("relativenumber", Observable.from_value(true), true, true)
  :register("transparency", Observable.from_value(false), true, true)

---@param params                        ghc.types.context.client.IToggleSchemeParams
---@return nil
function context.toggle_scheme(params)
  local mode = params.mode or context.mode:snapshot() ---@type fml.enums.theme.Mode
  local transparency = fml.boolean.cover(params.transparency, context.transparency:snapshot()) ---@type boolean
  local persistent = fml.boolean.cover(params.persistent, false) ---@type boolean
  local force = fml.boolean.cover(params.force, false) ---@type boolean

  ---@type boolean
  local has_changed = context.mode:snapshot() ~= mode or context.transparency:snapshot() ~= transparency
  if has_changed then
    context.mode:next(mode)
    context.transparency:next(transparency)
  end

  if force or has_changed then
    theme.load_theme({ mode = mode, transparency = transparency, persistent = persistent, filepath = theme_cache_path })
  end
end

---@param params                        ghc.types.context.client.IReloadPartialThemeParams
---@return nil
function context.reload_partial(params)
  local integration = params.integration ---@type ghc.enum.ui.theme.HighlightIntegration
  local mode = context.mode:snapshot() ---@type fml.enums.theme.Mode
  local transparency = context.transparency:snapshot() ---@type boolean
  theme.load_partial_theme({ mode = mode, transparency = transparency, integration = integration })
end

---@param params                        ghc.types.context.client.IReloadThemeParams
---@return nil
function context.reload_theme(params)
  local force = params.force or false ---@type boolean
  local mode = context.mode:snapshot() ---@type fml.enums.theme.Mode
  local transparency = context.transparency:snapshot() ---@type boolean

  if force or not fml.path.is_exist(theme_cache_path) then
    context.toggle_scheme({ mode = mode, transparency = transparency, persistent = true, force = true })
  else
    dofile(theme_cache_path)
  end

  local scheme = theme.get_scheme(mode) ---@type fml.types.ui.theme.IScheme|nil
  if scheme ~= nil then
    theme.set_term_colors(scheme)
  end
end

context:load()
context:auto_reload({
  on_changed = function()
    vim.defer_fn(function()
      context.reload_theme({ force = false })
    end, 200)
  end,
})

---Auto refresh statusline
fml.fn.watch_observables({ context.mode, context.transparency }, function()
  vim.schedule(function()
    vim.cmd("redrawstatus")
  end)
end)

return context
