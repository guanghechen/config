local Observable = require("fml.collection.observable")
local Viewmodel = require("fml.collection.viewmodel")
local path = require("fml.core.path")
local watch_observables = require("fml.fn.watch_observables")

local context_filepath = path.locate_context_filepath({ filename = "theme.json" }) ---@type string
local cache_theme_filepath = path.locate_context_filepath({ filename = "theme" }) ---@type string

---@class fml.context.theme : fml.types.context.theme
local M = Viewmodel.new({
  name = "context:session:replace",
  filepath = context_filepath,
})
  :register("mode", Observable.from_value("darken"), true, true)
  :register("transparency", Observable.from_value(false), true, true)

---@param params                        fml.types.context.theme.IToggleSchemeParams
---@return nil
function M.toggle_scheme(params)
  local mode = params.mode or M.mode:get_snapshot() ---@type fml.enums.theme.Mode
  local transparency = params.transparency or M.transparency:get_snapshot() ---@type boolean
  local persistent = params.persistent or false ---@type boolean
  local force = params.force or false ---@type boolean

  ---@type boolean
  local has_changed = M.mode:get_snapshot() ~= mode or M.transparency:get_snapshot() ~= transparency

  if not has_changed and not force then
    return
  end

  local present_scheme, scheme = pcall(require, "fml.context.theme.scheme." .. mode)
  if not present_scheme then
    fml.reporter.error({
      from = "fml.context.theme",
      subject = "toggle_scheme",
      message = "Cannot find scheme",
      details = { mode = mode, transparency = transparency },
    })
    return
  end

  local present_hlconfig_map, hlconfig_map =
    pcall(require, transparency and "fml.context.theme.hlconfig_map_transparency" or "fml.context.theme.hlconfig_map")
  if not present_hlconfig_map then
    fml.reporter.error({
      from = "fml.context.theme",
      subject = "toggle_scheme",
      message = "Cannot find hlconfig map",
      details = { mode = mode, transparency = transparency },
    })
    return
  end

  local theme = fml.ui.Theme.new():registers(hlconfig_map)
  if persistent then
    theme:compile({ nsnr = 0, scheme = scheme, filepath = cache_theme_filepath })
    dofile(cache_theme_filepath)
  else
    theme:apply({ nsnr = 0, scheme = scheme })
  end

  M.mode:next(mode)
  M.transparency:next(transparency)
end

---@param params                        fml.types.context.theme.IReloadThemeParams
---@return nil
function M.reload_theme(params)
  local force = params.force or false ---@type boolean
  if force or not fml.path.is_exist(cache_theme_filepath) then
    local mode = M.mode:get_snapshot() ---@type fml.enums.theme.Mode
    local transparency = M.transparency:get_snapshot() ---@type boolean
    M.toggle_scheme({ mode = mode, transparency = transparency, persistent = true, force = true })
  else
    dofile(cache_theme_filepath)
  end
end

M:load()
M:auto_reload()

---Auto refresh statusline
watch_observables({
  M.mode,
  M.transparency,
}, function()
  vim.cmd("redrawstatus")
end)

return M
