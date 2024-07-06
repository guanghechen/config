local theme = require("ghc.ui.theme")
local Observable = fml.collection.Observable
local Viewmodel = fml.collection.Viewmodel

local context_filepath = fml.path.locate_context_filepath({ filename = "shared.json" }) ---@type string
local theme_cache_path = fml.path.locate_context_filepath({ filename = "theme" }) ---@type string

---@class ghc.context.shared : ghc.types.context.shared
---@field public mode                   fml.types.collection.IObservable
---@field public relativenumber         fml.types.collection.IObservable
---@field public transparency           fml.types.collection.IObservable
local M = Viewmodel.new({
      name = "context:theme",
      filepath = context_filepath,
      verbose = true,
    })
    :register("mode", Observable.from_value("darken"), true, true)
    :register("relativenumber", Observable.from_value(true), true, true)
    :register("transparency", Observable.from_value(false), true, true)

---@param params                        ghc.types.context.shared.IToggleSchemeParams
---@return nil
function M.toggle_scheme(params)
  local mode = params.mode or M.mode:get_snapshot() ---@type fml.enums.theme.Mode
  local transparency = params.transparency or M.transparency:get_snapshot() ---@type boolean
  local persistent = params.persistent or false ---@type boolean
  local force = params.force or false ---@type boolean

  ---@type boolean
  local has_changed = M.mode:get_snapshot() ~= mode or M.transparency:get_snapshot() ~= transparency
  if has_changed then
    M.mode:next(mode)
    M.transparency:next(transparency)
  end

  if force or has_changed then
    theme.load_theme({ mode = mode, transparency = transparency, persistent = persistent, filepath = theme_cache_path })
  end
end

---@param params                        ghc.types.context.shared.IReloadPartialThemeParams
---@return nil
function M.reload_partial(params)
  local integration = params.integration ---@type ghc.enum.ui.theme.HighlightIntegration
  local mode = M.mode:get_snapshot() ---@type fml.enums.theme.Mode
  local transparency = M.transparency:get_snapshot() ---@type boolean
  theme.load_partial_theme({ mode = mode, transparency = transparency, integration = integration })
end

---@param params                        ghc.types.context.shared.IReloadThemeParams
---@return nil
function M.reload_theme(params)
  local force = params.force or false ---@type boolean
  local mode = M.mode:get_snapshot() ---@type fml.enums.theme.Mode
  local transparency = M.transparency:get_snapshot() ---@type boolean

  if force or not fml.path.is_exist(theme_cache_path) then
    M.toggle_scheme({ mode = mode, transparency = transparency, persistent = true, force = true })
  else
    dofile(theme_cache_path)
  end

  local scheme = theme.get_scheme(mode) ---@type fml.types.ui.theme.IScheme|nil
  if scheme ~= nil then
    theme.set_term_colors(scheme)
  end
end

M:load()
M:auto_reload({
  on_changed = function()
    M.reload_theme({ force = true })
  end,
})

---Auto refresh statusline
fml.fn.watch_observables({ M.mode, M.transparency }, function()
  vim.schedule(function()
    vim.cmd("redrawstatus")
  end)
end)

return M
