local theme = require("ghc.ui.theme")
local client = require("ghc.context.client")

local theme_cache_path = eve.path.locate_context_filepath({ filename = "theme" }) ---@type string

---@class ghc.command.theme
local M = {}

---@param params                        ghc.types.context.client.IToggleSchemeParams
---@return nil
function M.toggle_scheme(params)
  local mode = params.mode or client.theme:snapshot() ---@type fml.enums.theme.Mode
  local transparency = eve.boolean.cover(params.transparency, client.transparency:snapshot()) ---@type boolean
  local persistent = eve.boolean.cover(params.persistent, false) ---@type boolean
  local force = eve.boolean.cover(params.force, false) ---@type boolean

  ---@type boolean
  local has_changed = client.theme:snapshot() ~= mode or client.transparency:snapshot() ~= transparency
  if has_changed then
    client.theme:next(mode)
    client.transparency:next(transparency)
  end

  if force or has_changed then
    theme.load_theme({ mode = mode, transparency = transparency, persistent = persistent, filepath = theme_cache_path })
  end
end

---@param params                        ghc.types.context.client.IReloadPartialThemeParams
---@return nil
function M.reload_partial(params)
  local integration = params.integration ---@type ghc.enum.ui.theme.HighlightIntegration
  local mode = client.theme:snapshot() ---@type fml.enums.theme.Mode
  local transparency = client.transparency:snapshot() ---@type boolean
  theme.load_partial_theme({ mode = mode, transparency = transparency, integration = integration })
end

---@param params                        ghc.types.context.client.IReloadThemeParams
---@return nil
function M.reload_theme(params)
  local force = params.force or false ---@type boolean
  local mode = client.theme:snapshot() ---@type fml.enums.theme.Mode
  local transparency = client.transparency:snapshot() ---@type boolean

  if force or not eve.path.is_exist(theme_cache_path) then
    M.toggle_scheme({ mode = mode, transparency = transparency, persistent = true, force = true })
  else
    dofile(theme_cache_path)
  end

  local scheme = theme.get_scheme(mode) ---@type fml.types.ui.theme.IScheme|nil
  if scheme ~= nil then
    theme.set_term_colors(scheme)
  end
end

return M
