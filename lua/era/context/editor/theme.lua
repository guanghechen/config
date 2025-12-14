local __module_name__ = "era.context.editor.theme" ---@type string

---@class era.context.theme.ILoadIntegrationParams
---@field public theme                  dot.e.ThemeFullName
---@field public transparency           boolean
---@field public integration            dot.e.ThemeIntegration
---@field public nsnr                   ?integer

---@class era.context.theme.ILoadThemeParams
---@field public theme                  dot.e.ThemeFullName
---@field public transparency           boolean
---@field public persistent             boolean
---@field public nsnr                   ?integer

---@class era.context.theme.data
---@field public theme                  dot.e.ThemeFullName
---@field public transparency           boolean
---@field public username               boolean

---@class era.context.theme.state
---@field public theme                  ark.c.Observable
---@field public transparency           ark.c.Observable
---@field public username               ark.c.Observable
---
---@field public get_float_winblend     fun(): integer
---
---@field public apply_integration      fun(params: era.context.theme.ILoadIntegrationParams): nil
---@field public apply_theme            fun(params: era.context.theme.ILoadThemeParams): nil
---@field public get_scheme             fun(theme: dot.e.ThemeFullName): dot.t.theme.IScheme | nil
---@field public reload_theme           fun(force: boolean, reload_plugins: boolean): nil
---@field public set_term_colors        fun(scheme: dot.t.theme.IScheme): nil

---@class era.context.theme :  era.context.theme.state
---@field public defaults               fun(): era.context.theme.data
---@field public dump                   fun(): era.context.theme.data
---@field public load                   fun(data: unknown): nil
---@field public normalize              fun(data: unknown): era.context.theme.data
local M = {}

---@type dot.e.ThemeIntegration[]
local integrations = {
  "common",
  "basic",
  "lsp",
  "nvimbar",
  "widget",
  "treesitter",
  "plugin",
}

---@return string
local function get_theme_path()
  return dot.path.locate_context_filepath("theme")
end

---@return era.context.theme.data
function M.defaults()
  ---@type era.context.theme.data
  return {
    theme = "gruvbox-dark",
    transparency = true,
    username = false,
  }
end

---@param data                          any
---@return era.context.theme.data
function M.normalize(data)
  local resolved = M.defaults() ---@type era.context.theme.data
  if type(data) == "table" then
    if type(data.theme) == "string" and vim.list_contains(dot.var.theme, data.theme) then
      resolved.theme = data.theme
    end
    if type(data.transparency) == "boolean" then
      resolved.transparency = data.transparency
    end
    if type(data.username) == "boolean" then
      resolved.username = data.username
    end
  end

  ---@type era.context.theme.data
  return resolved
end

---@return era.context.theme.data
function M.dump()
  ---@type era.context.theme.data
  return {
    theme = M.theme:snapshot(),
    transparency = M.transparency:snapshot(),
    username = M.username:snapshot(),
  }
end

---@param raw_data                      any
function M.load(raw_data)
  local data = M.normalize(raw_data) ---@type era.context.theme.data
  M.theme:next(data.theme)
  M.transparency:next(data.transparency)
  M.username:next(data.username)
end

----------------------------------------------------------------------------------------------------

local _defaults = M.defaults() ---@type era.context.theme.data
M.theme = ark.c.Observable.from_value(_defaults.theme)
M.transparency = ark.c.Observable.from_value(_defaults.transparency)
M.username = ark.c.Observable.from_value(_defaults.username)

---@return integer
function M.get_float_winblend()
  return M.transparency:snapshot() and 5 or 0 ---@type integer
end

---@param params                        era.context.theme.ILoadIntegrationParams
---@return nil
function M.apply_integration(params)
  local theme = params.theme ---@type dot.e.ThemeFullName
  local transparency = params.transparency ---@type boolean
  local integration = params.integration ---@type dot.e.ThemeIntegration
  local nsnr = params.nsnr or 0 ---@type integer

  local scheme = M.get_scheme(theme)
  if scheme ~= nil then
    ---@type dot.t.theme.IContext
    local themeContext = {
      theme = scheme.theme,
      variant = scheme.variant,
      scheme = scheme,
      transparency = transparency,
    }
    local h = dot.theme.hlgroup[integration]
    local hlgroup_map = h.gen_hlgroup_map(themeContext)
    local uxTheme = dot.theme.Namespace.new()
    uxTheme:registers(hlgroup_map)
    uxTheme:apply({ nsnr = nsnr, scheme = scheme })
  end
end

---@param params                        era.context.theme.ILoadThemeParams
---@return nil
function M.apply_theme(params)
  local theme = params.theme ---@type dot.e.ThemeFullName
  local transparency = params.transparency ---@type boolean
  local persistent = params.persistent ---@type boolean
  local nsnr = params.nsnr or 0 ---@type integer

  local scheme = M.get_scheme(theme)
  if scheme ~= nil then
    vim.g.colors_name = theme
    vim.o.background = scheme.darken and "dark" or "light"

    ---@type dot.theme.hlgroup.nvimbar
    local nvimbar_hlgroup_map = dot.theme.hlgroup.nvimbar.gen_hlgroup_map({
      theme = theme,
      scheme = scheme,
      transparency = transparency,
    })

    local uxTheme = dot.theme.Namespace.new()
    for _, integration in ipairs(integrations) do
      local h = dot.theme.hlgroup[integration]
      ---@return table<string, dot.t.theme.IHlgroup>
      local hlgroup_map = h.gen_hlgroup_map({ scheme = scheme, transparency = transparency })

      if integration == "plugin" then
        local additional = {} ---@type table<string, dot.t.theme.IHlgroup>
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

---@param theme                         dot.e.ThemeFullName
---@return dot.t.theme.IScheme | nil
function M.get_scheme(theme)
  if not vim.list_contains(dot.var.theme, theme) then
    ark.reporter.error({
      from = __module_name__,
      subject = "get_scheme",
      message = "Unknown theme.",
      details = { theme = theme },
    })
    return nil
  end
  return dot.theme.scheme[theme]
end

---@param force                         boolean
---@param reload_plugins                boolean
---@return nil
function M.reload_theme(force, reload_plugins)
  local theme = M.theme:snapshot() ---@type dot.e.ThemeFullName
  local transparency = M.transparency:snapshot() ---@type boolean

  local scheme = M.get_scheme(theme) ---@type dot.t.theme.IScheme|nil
  if scheme ~= nil then
    vim.g.colors_name = theme
    vim.o.background = scheme.darken and "dark" or "light"
  end

  local theme_path = get_theme_path() ---@type string
  if force or not yoz.path.is_exist(theme_path) then
    M.apply_theme({
      theme = theme,
      transparency = transparency,
      persistent = true,
      filepath = theme_path,
    })
  else
    local ok, err = pcall(dofile, theme_path)
    if not ok then
      ark.reporter.error({
        from = __module_name__,
        subject = "reload_theme",
        message = "Bad theme file.",
        details = { force = force, reload_plugins = reload_plugins, theme_path = theme_path, error = err },
      })
    end

    -- local scheme = M.get_scheme(theme) ---@type dot.t.theme.IScheme|nil
    -- if scheme ~= nil then
    -- M.set_term_colors(scheme)
    -- end
  end
end

--- Set the term color with the specific value (hex).
--- Since we also changed the terminal color outside, so no need to set it again,
--- so we can get the terminal color automatically changed by the terminal itself
--- since we used the color name instead of a specific value (hex).
---@param scheme                        dot.t.theme.IScheme
---@return nil
function M.set_term_colors(scheme)
  local c = scheme.palette.unified ---@type dot.t.theme.UnifiedPalette
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
