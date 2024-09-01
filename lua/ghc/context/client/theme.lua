local theme = require("ghc.ui.theme")
local Observable = fml.collection.Observable

local theme_cache_path = fc.path.locate_context_filepath({ filename = "theme" }) ---@type string

---@class ghc.context.client
---@field public mode                   fml.types.collection.IObservable
---@field public transparency           fml.types.collection.IObservable
local M = require("ghc.context.client.mod")
  ---
  :register("mode", Observable.from_value("darken"), true, true)
  :register("transparency", Observable.from_value(false), true, true)

---@param params                        ghc.types.context.client.IToggleSchemeParams
---@return nil
function M.toggle_scheme(params)
  local mode = params.mode or M.mode:snapshot() ---@type fml.enums.theme.Mode
  local transparency = fc.boolean.cover(params.transparency, M.transparency:snapshot()) ---@type boolean
  local persistent = fc.boolean.cover(params.persistent, false) ---@type boolean
  local force = fc.boolean.cover(params.force, false) ---@type boolean

  ---@type boolean
  local has_changed = M.mode:snapshot() ~= mode or M.transparency:snapshot() ~= transparency
  if has_changed then
    M.mode:next(mode)
    M.transparency:next(transparency)
  end

  if force or has_changed then
    theme.load_theme({ mode = mode, transparency = transparency, persistent = persistent, filepath = theme_cache_path })
  end
end

---@param params                        ghc.types.context.client.IReloadPartialThemeParams
---@return nil
function M.reload_partial(params)
  local integration = params.integration ---@type ghc.enum.ui.theme.HighlightIntegration
  local mode = M.mode:snapshot() ---@type fml.enums.theme.Mode
  local transparency = M.transparency:snapshot() ---@type boolean
  theme.load_partial_theme({ mode = mode, transparency = transparency, integration = integration })
end

---@param params                        ghc.types.context.client.IReloadThemeParams
---@return nil
function M.reload_theme(params)
  local force = params.force or false ---@type boolean
  local mode = M.mode:snapshot() ---@type fml.enums.theme.Mode
  local transparency = M.transparency:snapshot() ---@type boolean

  if force or not fc.path.is_exist(theme_cache_path) then
    M.toggle_scheme({ mode = mode, transparency = transparency, persistent = true, force = true })
  else
    dofile(theme_cache_path)
  end

  local scheme = theme.get_scheme(mode) ---@type fml.types.ui.theme.IScheme|nil
  if scheme ~= nil then
    theme.set_term_colors(scheme)
  end
end

---Auto refresh statusline
vim.schedule(function()
  fml.fn.watch_observables({
    M.mode,
    M.transparency,
  }, function()
    vim.cmd("redrawstatus")
  end)
end)
