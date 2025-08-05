local __module_name__ = "eve.status.theme" ---@type string

---@class eve.context.theme.ILoadIntegrationParams
---@field public theme                  std.e.ThemeFullName
---@field public transparency           boolean
---@field public integration            std.e.ThemeIntegration
---@field public nsnr                   ?integer

---@class eve.context.theme.ILoadThemeParams
---@field public theme                  std.e.ThemeFullName
---@field public transparency           boolean
---@field public persistent             boolean
---@field public nsnr                   ?integer

---@class eve.context.theme.data
---@field public theme                  std.e.ThemeFullName
---@field public transparency           boolean
---@field public username               boolean

---@class eve.context.theme.state
---@field public theme                  std.collection.IObservable
---@field public transparency           std.collection.IObservable
---@field public username               std.collection.IObservable
---
---@field public get_float_winblend     fun(): integer
---
---@field public apply_integration      fun(params: eve.context.theme.ILoadIntegrationParams): nil
---@field public apply_theme            fun(params: eve.context.theme.ILoadThemeParams): nil
---@field public get_scheme             fun(theme: std.e.ThemeFullName): std.t.theme.IScheme | nil
---@field public reload_theme           fun(force: boolean, reload_plugins: boolean): nil
---@field public set_term_colors        fun(scheme: std.t.theme.IScheme): nil

---@class eve.context.theme :  eve.context.theme.state
---@field public defaults               fun(): eve.context.theme.data
---@field public dump                   fun(): eve.context.theme.data
---@field public load                   fun(data: unknown): nil
---@field public normalize              fun(data: unknown): eve.context.theme.data
local M = {}

---@type std.e.ThemeIntegration[]
local integrations = {
  "common",
  "basic",
  "nvimbar",
  "widget",
  "treesitter",
  "plugin",
}

---@return string
local function get_theme_path()
  return std.path.locate_context_filepath("theme")
end

---@return eve.context.theme.data
function M.defaults()
  ---@type eve.context.theme.data
  return {
    theme = "catppuccin-mocha",
    transparency = false,
    username = true,
  }
end

---@param data                        any
---@return eve.context.theme.data
function M.normalize(data)
  local resolved = M.defaults() ---@type eve.context.theme.data
  if type(data) == "table" then
    if type(data.theme) == "string" and vim.list_contains(eve.setting.themes, data.theme) then
      resolved.theme = data.theme
    end
    if type(data.transparency) == "boolean" then
      resolved.transparency = data.transparency
    end
    if type(data.username) == "boolean" then
      resolved.username = data.username
    end
  end

  ---@type eve.context.theme.data
  return resolved
end

---@return eve.context.theme.data
function M.dump()
  ---@type eve.context.theme.data
  return {
    theme = M.theme:snapshot(),
    transparency = M.transparency:snapshot(),
    username = M.username:snapshot(),
  }
end

---@param raw_data                      any
function M.load(raw_data)
  local data = M.normalize(raw_data) ---@type eve.context.theme.data
  M.theme:next(data.theme)
  M.transparency:next(data.transparency)
  M.username:next(data.username)
end

----------------------------------------------------------------------------------------------------

local _defaults = M.defaults() ---@type eve.context.theme.data
M.theme = std.Observable.from_value(_defaults.theme)
M.transparency = std.Observable.from_value(_defaults.transparency)
M.username = std.Observable.from_value(_defaults.username)

---@return integer
function M.get_float_winblend()
  return M.transparency:snapshot() and 15 or 0 ---@type integer
end

---@param params                        eve.context.theme.ILoadIntegrationParams
---@return nil
function M.apply_integration(params)
  local theme = params.theme ---@type std.e.ThemeFullName
  local transparency = params.transparency ---@type boolean
  local integration = params.integration ---@type std.e.ThemeIntegration
  local nsnr = params.nsnr or 0 ---@type integer

  local scheme = M.get_scheme(theme)
  if scheme ~= nil then
    ---@type std.t.theme.IContext
    local themeContext = {
      theme = scheme.theme,
      variant = scheme.variant,
      scheme = scheme,
      transparency = transparency,
    }
    local h = require("eve.constant.hlgroup." .. integration)
    local hlgroup_map = h.gen_hlgroup_map(themeContext)
    local uxTheme = std.Theme.new()
    uxTheme:registers(hlgroup_map)
    uxTheme:apply({ nsnr = nsnr, scheme = scheme })
  end
end

---@param params                        eve.context.theme.ILoadThemeParams
---@return nil
function M.apply_theme(params)
  local theme = params.theme ---@type std.e.ThemeFullName
  local transparency = params.transparency ---@type boolean
  local persistent = params.persistent ---@type boolean
  local nsnr = params.nsnr or 0 ---@type integer

  local scheme = M.get_scheme(theme)
  if scheme ~= nil then
    local h_nvimbar = require("eve.constant.hlgroup.nvimbar")

    ---@type eve.constant.hlgroup.nvimbar
    local nvimbar_hlgroup_map = h_nvimbar.gen_hlgroup_map({
      theme = theme,
      scheme = scheme,
      transparency = transparency,
    })

    local uxTheme = std.Theme.new()
    for _, integration in ipairs(integrations) do
      local h = require("eve.constant.hlgroup." .. integration)
      ---@return table<string, std.t.theme.IHlgroup>
      local hlgroup_map = h.gen_hlgroup_map({ scheme = scheme, transparency = transparency })

      if integration == "plugin" then
        local additional = {} ---@type table<string, std.t.theme.IHlgroup>
        for hlname, hlgroup in pairs(hlgroup_map) do
          if string.sub(hlname, 1, 9) == "MiniIcons" then
            additional["f_sl_" .. hlname] = { fg = hlgroup.fg, bg = nvimbar_hlgroup_map.f_sl_bg.bg }
            additional["f_tl_" .. hlname] = { fg = hlgroup.fg, bg = nvimbar_hlgroup_map.f_tl_bg.bg }
            additional["f_wl_" .. hlname] = { fg = hlgroup.fg, bg = nvimbar_hlgroup_map.f_wl_bg.bg }

            additional["f_sl_buf_" .. hlname] = { fg = hlgroup.fg, bg = nvimbar_hlgroup_map.f_sl_buf.bg }
            additional["f_tl_buf_" .. hlname] = { fg = hlgroup.fg, bg = nvimbar_hlgroup_map.f_tl_buf.bg }
            additional["f_wl_buf_" .. hlname] = { fg = hlgroup.fg, bg = nvimbar_hlgroup_map.f_wl_buf.bg }

            additional["f_sl_bufc_" .. hlname] = {
              fg = hlgroup.fg,
              bg = nvimbar_hlgroup_map.f_sl_bufc.bg,
            }
            additional["f_tl_bufc_" .. hlname] = {
              fg = hlgroup.fg,
              bg = nvimbar_hlgroup_map.f_tl_bufc.bg,
            }
            additional["f_wl_bufc_" .. hlname] = {
              fg = hlgroup.fg,
              bg = nvimbar_hlgroup_map.f_wl_bufc.bg,
            }
          end
        end

        for hlname, hlgroup in pairs(additional) do
          hlgroup_map[hlname] = hlgroup
        end
      end

      uxTheme:registers(hlgroup_map)
    end

    uxTheme:apply({ nsnr = nsnr, scheme = scheme })
    if persistent then
      local theme_path = get_theme_path() ---@type string
      uxTheme:compile({ nsnr = 0, scheme = scheme, filepath = theme_path })
    end
    -- M.set_term_colors(scheme)
  end

  return scheme
end

---@param theme                         std.e.ThemeFullName
---@return std.t.theme.IScheme | nil
function M.get_scheme(theme)
  if not vim.list_contains(eve.setting.themes, theme) then
    std.reporter.error({
      from = __module_name__,
      subject = "get_scheme",
      message = "Unknown theme.",
      details = { theme = theme },
    })
    return nil
  end
  return require("eve.constant.theme." .. theme)
end

---@param force                         boolean
---@param reload_plugins                boolean
---@return nil
function M.reload_theme(force, reload_plugins)
  local theme = M.theme:snapshot() ---@type std.e.ThemeFullName
  local transparency = M.transparency:snapshot() ---@type boolean

  local scheme = M.get_scheme(theme) ---@type std.t.theme.IScheme|nil
  if scheme ~= nil then
    vim.o.background = scheme.darken and "dark" or "light"
  end

  local theme_path = get_theme_path() ---@type string
  if force or not std.path.is_exist(theme_path) then
    M.apply_theme({
      theme = theme,
      transparency = transparency,
      persistent = true,
      filepath = theme_path,
    })
  else
    local ok, err = pcall(dofile, theme_path)
    if not ok then
      std.reporter.error({
        from = __module_name__,
        subject = "reload_theme",
        message = "Bad theme file.",
        details = { force = force, reload_plugins = reload_plugins, theme_path = theme_path, error = err },
      })
    end

    -- local scheme = M.get_scheme(theme) ---@type std.t.theme.IScheme|nil
    -- if scheme ~= nil then
    -- M.set_term_colors(scheme)
    -- end
  end
end

--- Set the term color with the specific value (hex).
--- Since we also changed the terminal color outside, so no need to set it again,
--- so we can get the terminal color automatically changed by the terminal itself
--- since we used the color name instead of a specific value (hex).
---@param scheme                        std.t.theme.IScheme
---@return nil
function M.set_term_colors(scheme)
  local c = scheme.palette.unified ---@type std.t.theme.IUnifiedPalette
  vim.g.terminal_color_0 = c.bg0
  vim.g.terminal_color_1 = c.red
  vim.g.terminal_color_2 = c.green
  vim.g.terminal_color_3 = c.yellow
  vim.g.terminal_color_4 = c.blue
  vim.g.terminal_color_5 = c.purple
  vim.g.terminal_color_6 = c.aqua
  vim.g.terminal_color_7 = c.fg1
  vim.g.terminal_color_8 = c.bg0
  vim.g.terminal_color_9 = c.brightRed
  vim.g.terminal_color_10 = c.brightGreen
  vim.g.terminal_color_11 = c.brightYellow
  vim.g.terminal_color_12 = c.brightBlue
  vim.g.terminal_color_13 = c.brightPurple
  vim.g.terminal_color_14 = c.brightAqua
  vim.g.terminal_color_15 = c.fg1
end

return M
