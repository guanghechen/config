local gen_hlconfig_map = require("ghc.ui.theme.hlconfig")
local Theme = fml.ui.Theme
local Observable = fml.collection.Observable
local Viewmodel = fml.collection.Viewmodel

local context_filepath = fml.path.locate_context_filepath({ filename = "theme.json" }) ---@type string
local cache_theme_filepath = fml.path.locate_context_filepath({ filename = "theme" }) ---@type string

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

---@param mode                         fml.enums.theme.Mode
---@param transparency                 boolean
---@return nil
local function load_nvchad_theme(mode, transparency)
  local present_nvconfig, nvconfig = pcall(require, "nvconfig")
  local preset_base46, base46 = pcall(require, "base46")
  if present_nvconfig and preset_base46 then
    local current_theme = mode == "darken" and "onedark" or "one_light" ---@type string
    nvconfig.ui.theme = current_theme
    nvconfig.ui.transparency = transparency
    base46.load_all_highlights()
  end
end

---@class ghc.context.shared.ILoadThemeParams
---@field public mode                   fml.enums.theme.Mode
---@field public transparency           boolean
---@field public persistent             boolean

---@param params                        ghc.context.shared.ILoadThemeParams
---@return nil
local function load_theme(params)
  local mode = params.mode ---@type fml.enums.theme.Mode
  local transparency = params.transparency ---@type boolean
  local persistent = params.persistent ---@type boolean

  local present_scheme, scheme = pcall(require, "ghc.ui.theme.scheme." .. mode)
  if not present_scheme then
    fml.reporter.error({
      from = "ghc.context.shared",
      subject = "toggle_scheme",
      message = "Cannot find scheme",
      details = { mode = mode, transparency = transparency, persistent = persistent },
    })
    return
  end

  local hlconfig_map = gen_hlconfig_map({ transparency = transparency })
  local theme = Theme.new():registers(hlconfig_map)
  vim.schedule(function ()
    if persistent then
      theme:compile({ nsnr = 0, scheme = scheme, filepath = cache_theme_filepath })
      dofile(cache_theme_filepath)
    else
      theme:apply({ nsnr = 0, scheme = scheme })
    end
  end)
end

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
    load_theme({ mode = mode, transparency = transparency, persistent = persistent })
    load_nvchad_theme(mode, transparency)
  end
end

---@param params                        ghc.types.context.shared.IReloadThemeParams
---@return nil
function M.reload_theme(params)
  local force = params.force or false ---@type boolean
  local mode = M.mode:get_snapshot() ---@type fml.enums.theme.Mode
  local transparency = M.transparency:get_snapshot() ---@type boolean
  if force or not fml.path.is_exist(cache_theme_filepath) then
    M.toggle_scheme({ mode = mode, transparency = transparency, persistent = true, force = true })
  else
    dofile(cache_theme_filepath)
    load_nvchad_theme(mode, transparency)
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
  vim.cmd("redrawstatus")
end)

return M
