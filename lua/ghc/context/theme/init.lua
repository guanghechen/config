local gen_hlconfig_map = require("ghc.context.theme.hlconfig")
local Theme = require("ghc.ui.theme")
local Observable = fml.collection.Observable
local Viewmodel = fml.collection.Viewmodel

local context_filepath = fml.path.locate_context_filepath({ filename = "theme.json" }) ---@type string
local cache_theme_filepath = fml.path.locate_context_filepath({ filename = "theme" }) ---@type string

---@class ghc.context.theme : ghc.types.context.theme
local M = Viewmodel.new({
  name = "context:theme",
  filepath = context_filepath,
})
  :register("mode", Observable.from_value("darken"), true, true)
  :register("transparency", Observable.from_value(false), true, true)

---@param params                        ghc.types.context.theme.IToggleSchemeParams
---@return nil
function M.toggle_scheme(params)
  local mode = params.mode or M.mode:get_snapshot() ---@type ghc.enums.theme.Mode
  local transparency = params.transparency or M.transparency:get_snapshot() ---@type boolean
  local persistent = params.persistent or false ---@type boolean
  local force = params.force or false ---@type boolean

  ---@type boolean
  local has_changed = M.mode:get_snapshot() ~= mode or M.transparency:get_snapshot() ~= transparency

  if not has_changed and not force then
    return
  end

  local present_scheme, scheme = pcall(require, "ghc.context.theme.scheme." .. mode)
  if not present_scheme then
    fml.reporter.error({
      from = "ghc.context.theme",
      subject = "toggle_scheme",
      message = "Cannot find scheme",
      details = { mode = mode, transparency = transparency },
    })
    return
  end

  local hlconfig_map = gen_hlconfig_map({ transparency = transparency })
  local theme = Theme.new():registers(hlconfig_map)
  if persistent then
    theme:compile({ nsnr = 0, scheme = scheme, filepath = cache_theme_filepath })
    dofile(cache_theme_filepath)
  else
    theme:apply({ nsnr = 0, scheme = scheme })
  end

  M.mode:next(mode)
  M.transparency:next(transparency)
end

---@param params                        ghc.types.context.theme.IReloadThemeParams
---@return nil
function M.reload_theme(params)
  local force = params.force or false ---@type boolean
  if force or not fml.path.is_exist(cache_theme_filepath) then
    local mode = M.mode:get_snapshot() ---@type ghc.enums.theme.Mode
    local transparency = M.transparency:get_snapshot() ---@type boolean
    M.toggle_scheme({ mode = mode, transparency = transparency, persistent = true, force = true })
  else
    dofile(cache_theme_filepath)
  end
end

M:load()
M:auto_reload()

---Auto refresh statusline
fml.fn.watch_observables({
  M.mode,
  M.transparency,
}, function()
  vim.cmd("redrawstatus")
end)

return M
