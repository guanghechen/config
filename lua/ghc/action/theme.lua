local devmode = eve.context.state.flight.devmode:snapshot() ---@type boolean
local hmr = devmode and eve.util.hmr or require

local uxTheme = require("ghc.ux.theme")
local theme_cache_path = eve.path.locate_theme_filepath("theme")

---@class ghc.action.theme.ILoadThemeParams
---@field public theme                  t.eve.e.Theme
---@field public mode                   t.eve.e.ThemeMode
---@field public transparency           boolean
---@field public persistent             boolean
---@field public filepath               ?string
---@field public nsnr                   ?integer

---@class ghc.action.theme.IToggleSchemeParams
---@field public theme                  ?t.eve.e.Theme
---@field public mode                   ?t.eve.e.ThemeMode
---@field public transparency           ?boolean
---@field public persistent             ?boolean
---@field public force                  ?boolean

---@class ghc.action.theme.IReloadPartialParams
---@field public integration            t.ghc.e.ux.theme.HighlightIntegration
---@field public nsnr                   ?integer

---@class ghc.action.theme.IReloadThemeParams
---@field public force                  ?boolean

---@class ghc.action.theme
local M = {}

---@return nil
function M.toggle_transparency()
  local flag = eve.context.state.theme.transparency:snapshot() ---@type boolean
  eve.context.state.theme.transparency:next(not flag)
end

---@return nil
function M.toggle_relativenumber()
  local flag = eve.context.state.theme.relativenumber:snapshot() ---@type boolean
  eve.context.state.theme.relativenumber:next(not flag)

  if vim.o.nu then
    vim.opt.relativenumber = not flag
    vim.cmd.redraw()
  end
end

---@param params                        ghc.action.theme.IToggleSchemeParams
---@return nil
function M.toggle_scheme(params)
  local next_theme = params.theme or eve.context.state.theme.theme:snapshot() ---@type t.eve.e.Theme
  local next_mode = params.mode or eve.context.state.theme.mode:snapshot() ---@type t.eve.e.ThemeMode
  local next_transparency = eve.boolean.cover(params.transparency, eve.context.state.theme.transparency:snapshot()) ---@type boolean
  local persistent = eve.boolean.cover(params.persistent, false) ---@type boolean
  local force = eve.boolean.cover(params.force, false) ---@type boolean

  ---@type boolean
  local has_changed = eve.context.state.theme.theme:snapshot() ~= next_theme
    or eve.context.state.theme.mode:snapshot() ~= next_mode
    or eve.context.state.theme.transparency:snapshot() ~= next_transparency
  if has_changed then
    eve.context.state.theme.theme:next(next_theme)
    eve.context.state.theme.mode:next(next_mode)
    eve.context.state.theme.transparency:next(next_transparency)
  end

  if force or has_changed then
    local themeScheme = uxTheme.load_theme({
      theme = next_theme,
      mode = next_mode,
      transparency = next_transparency,
      persistent = persistent,
      filepath = theme_cache_path,
    })

    if themeScheme ~= nil then
      eve.context.state.theme.mode:next(themeScheme.mode)
    end
  end
end

---@return nil
function M.toggle_mode()
  local mode = eve.context.state.theme.mode:snapshot() ---@type t.eve.e.ThemeMode
  local next_mode = mode == "light" and "dark" or "light"
  M.toggle_scheme({ mode = next_mode, persistent = true })
end

---@return nil
function M.toggle_wrap_tmp()
  ---@diagnostic disable-next-line: undefined-field
  local wrap = vim.opt_local.wrap:get() ---@type boolean
  vim.opt_local.wrap = not wrap
end

---@param params                        ghc.action.theme.IReloadPartialParams
---@return nil
function M.reload_partial(params)
  local nsnr = params.nsnr or 0 ---@type integer
  local integration = params.integration ---@type t.ghc.e.ux.theme.HighlightIntegration
  uxTheme.load_integration(nsnr, integration)
end

---@param params                        ghc.action.theme.IReloadThemeParams
---@return nil
function M.reload_theme(params)
  local force = params.force or false ---@type boolean
  local theme = eve.context.state.theme.theme:snapshot() ---@type t.eve.e.Theme
  local mode = eve.context.state.theme.mode:snapshot() ---@type t.eve.e.ThemeMode
  local transparency = eve.context.state.theme.transparency:snapshot() ---@type boolean

  if force or not eve.path.is_exist(theme_cache_path) then
    M.toggle_scheme({
      theme = theme,
      mode = mode,
      transparency = transparency,
      persistent = true,
      force = true,
    })
  else
    dofile(theme_cache_path)
  end

  local scheme = uxTheme.get_scheme(theme, mode) ---@type t.fml.ux.theme.IScheme|nil
  if scheme ~= nil then
    uxTheme.set_term_colors(scheme)
  end
end

---@return nil
function M.select_theme()
  local themes = {
    "gruvbox_dark",
    "gruvbox_light",
    "one_half_dark",
    "one_half_light",
  }

  fml.fn.select({
    title = "Select Theme",
    fetch_items = function()
      local items = {} ---@type t.fml.ux.select.IItem[]
      for _, theme in ipairs(themes) do
        table.insert(items, { uuid = theme, text = theme })
      end
      return items
    end,
    on_confirm = function(item)
      local theme = item.uuid ---@type string
      local ok, scheme = pcall(hmr, "ghc.ux.theme.scheme." .. theme)
      if ok then
        ---@cast scheme t.fml.ux.theme.IScheme
        M.toggle_scheme({
          mode = scheme.mode,
          theme = scheme.theme,
          persistent = true,
          force = false,
        })
      else
        eve.reporter.error({
          from = "ghc.action.theme",
          subject = "select_theme",
          message = "Failed to load theme scheme",
          details = { theme = theme, error = scheme },
        })
      end
    end,
  })
end

return M
