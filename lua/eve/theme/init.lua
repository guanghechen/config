local __module_name__ = "eve.theme" ---@type string

local path = require("eve.lib.path")
local reporter = require("eve.lib.reporter")
local state = require("eve.state")
local Theme = require("eve.theme.theme")

---@class eve.theme.IContext
---@field public theme                  string
---@field public scheme                 eve.theme.IScheme
---@field public transparency           boolean

---@class eve.theme.IApp
---@field public get_filepaths          fun(context: eve.theme.IContext): string[]
---@field public gen_theme              fun(context: eve.theme.IContext): string
---@field public after_written          ?fun(context: eve.theme.IContext): nil

---@alias eve.e.theme.HighlightIntegration
---|"basic"
---|"nvimbar"
---|"widget"
---|"treesitter"
---|"plugin"

---@class eve.theme.ILoadIntegrationParams
---@field public theme                  eve.e.Theme
---@field public transparency           boolean
---@field public integration            eve.e.theme.HighlightIntegration
---@field public nsnr                   ?integer

---@class eve.theme.ILoadThemeParams
---@field public theme                  eve.e.Theme
---@field public transparency           boolean
---@field public persistent             boolean
---@field public filepath               ?string
---@field public nsnr                   ?integer

---@class eve.theme
---@field public cache_path             string
---@field public themes                 eve.e.Theme[]
---@field public integrations           eve.e.theme.HighlightIntegration[]
local M = {
  cache_path = path.locate_context_filepath("theme"),
  themes = {
    "catppuccin-latte",
    "catppuccin-mocha",
    "gruvbox_dark",
    "gruvbox_light",
    "nord",
    "one_half_dark",
    "one_half_light",
  },
  integrations = {
    "basic",
    "nvimbar",
    "widget",
    "treesitter",
    "plugin",
  },
}

---@param params                        eve.theme.ILoadIntegrationParams
---@return nil
function M.apply_integration(params)
  local theme = params.theme ---@type eve.e.Theme
  local transparency = params.transparency ---@type boolean
  local integration = params.integration ---@type eve.e.theme.HighlightIntegration
  local nsnr = params.nsnr or 0 ---@type integer

  local scheme = M.get_scheme(theme)
  if scheme ~= nil then
    ---@type eve.theme.IContext
    local themeContext = {
      theme = scheme.theme,
      scheme = scheme,
      transparency = transparency,
    }
    local gen_hlgroup_map = state.hmr("eve.theme.integration." .. integration)
    local hlgroup_map = gen_hlgroup_map(themeContext)
    local uxTheme = Theme.new()
    uxTheme:registers(hlgroup_map)
    uxTheme:apply({ nsnr = nsnr, scheme = scheme })
  end
end

---@param params                        eve.theme.ILoadThemeParams
---@return eve.theme.IScheme|nil
function M.apply_theme(params)
  local theme = params.theme ---@type eve.e.Theme
  local transparency = params.transparency ---@type boolean
  local persistent = params.persistent ---@type boolean
  local filepath = params.filepath ---@type string|nil
  local nsnr = params.nsnr or 0 ---@type integer

  local scheme = M.get_scheme(theme)
  if scheme ~= nil then
    local gen_nvimbar_hlgroup_map = state.hmr("eve.theme.integration.nvimbar")

    ---@type eve.theme.integration.nvimbar.hlgroups
    local nvimbar_hlgroup_map = gen_nvimbar_hlgroup_map({ scheme = scheme, transparency = transparency })

    local uxTheme = Theme.new()
    for _, integration in ipairs(M.integrations) do
      local gen_hlgroup_map = state.hmr("eve.theme.integration." .. integration)
      ---@return table<string, eve.theme.IHlgroup>
      local hlgroup_map = gen_hlgroup_map({ scheme = scheme, transparency = transparency })

      if integration == "plugin" then
        local additional = {} ---@type table<string, eve.theme.IHlgroup>
        for hlname, hlgroup in pairs(hlgroup_map) do
          if hlname:sub(1, 9) == "MiniIcons" then
            additional["f_sl_" .. hlname] = { fg = hlgroup.fg, bg = nvimbar_hlgroup_map.f_sl_bg.bg }
            additional["f_tl_" .. hlname] = { fg = hlgroup.fg, bg = nvimbar_hlgroup_map.f_tl_bg.bg }
            additional["f_wl_" .. hlname] = { fg = hlgroup.fg, bg = nvimbar_hlgroup_map.f_wl_bg.bg }

            additional["f_sl_buf_" .. hlname] = { fg = hlgroup.fg, bg = nvimbar_hlgroup_map.f_sl_buf.bg }
            additional["f_tl_buf_" .. hlname] = { fg = hlgroup.fg, bg = nvimbar_hlgroup_map.f_tl_buf.bg }
            additional["f_wl_buf_" .. hlname] = { fg = hlgroup.fg, bg = nvimbar_hlgroup_map.f_wl_buf.bg }

            additional["f_sl_bufc_" .. hlname] = { fg = hlgroup.fg, bg = nvimbar_hlgroup_map.f_sl_bufc.bg }
            additional["f_tl_bufc_" .. hlname] = { fg = hlgroup.fg, bg = nvimbar_hlgroup_map.f_tl_bufc.bg }
            additional["f_wl_bufc_" .. hlname] = { fg = hlgroup.fg, bg = nvimbar_hlgroup_map.f_wl_bufc.bg }

            additional["f_sl_filename_" .. hlname] = { fg = hlgroup.fg, bg = nvimbar_hlgroup_map.f_sl_filename.bg }
            additional["f_tl_filename_" .. hlname] = { fg = hlgroup.fg, bg = nvimbar_hlgroup_map.f_tl_filename.bg }
            additional["f_wl_filename_" .. hlname] = { fg = hlgroup.fg, bg = nvimbar_hlgroup_map.f_wl_filename.bg }
          end
        end

        for hlname, hlgroup in pairs(additional) do
          hlgroup_map[hlname] = hlgroup
        end
      end

      uxTheme:registers(hlgroup_map)
    end

    uxTheme:apply({ nsnr = nsnr, scheme = scheme })
    if persistent and filepath ~= nil then
      uxTheme:compile({ nsnr = 0, scheme = scheme, filepath = filepath })
    end
    M.set_term_colors(scheme)
  end

  return scheme
end

---@param theme                         eve.e.Theme
---@return eve.theme.IScheme|nil
function M.get_scheme(theme)
  if not vim.tbl_contains(M.themes, theme) then
    reporter.error({
      from = __module_name__,
      subject = "get_scheme",
      message = "Unknown theme.",
      details = { theme = theme },
    })
    return nil
  end

  local ok, scheme = pcall(state.hmr, "eve.theme.scheme." .. theme)
  if not ok then
    reporter.error({
      from = __module_name__,
      subject = "get_scheme",
      message = "Cannot find scheme.",
      details = { theme = theme },
    })
    return nil
  end
  return scheme
end

---@param force                         boolean
---@param reload_plugins                boolean
---@return nil
function M.reload_theme(force, reload_plugins)
  local theme = state.theme.theme:snapshot() ---@type eve.e.Theme
  local transparency = state.theme.transparency:snapshot() ---@type boolean
  local theme_cache_path = M.cache_path ---@type string

  if force or not path.is_exist(theme_cache_path) then
    M.apply_theme({
      theme = theme,
      transparency = transparency,
      persistent = true,
      filepath = theme_cache_path,
    })
  else
    dofile(theme_cache_path)

    local scheme = M.get_scheme(theme) ---@type eve.theme.IScheme|nil
    if scheme ~= nil then
      M.set_term_colors(scheme)
    end
  end

  ---! Reload the plugins to trigger it to apply the new highlights.
  if reload_plugins then
    pcall(function()
      vim.cmd("Lazy reload indent-blankline.nvim")
    end)
  end
end

---@param scheme                        eve.theme.IScheme
---@return nil
function M.set_term_colors(scheme)
  local c = scheme.palette ---@type eve.theme.IPalette
  vim.g.terminal_color_0 = c.bg0
  vim.g.terminal_color_1 = c.red
  vim.g.terminal_color_2 = c.green
  vim.g.terminal_color_3 = c.yellow
  vim.g.terminal_color_4 = c.blue
  vim.g.terminal_color_5 = c.purple
  vim.g.terminal_color_6 = c.aqua
  vim.g.terminal_color_7 = c.fg4
  vim.g.terminal_color_8 = c.grey
  vim.g.terminal_color_9 = c.brightRed
  vim.g.terminal_color_10 = c.brightGreen
  vim.g.terminal_color_11 = c.brightYellow
  vim.g.terminal_color_12 = c.brightBlue
  vim.g.terminal_color_13 = c.brightPurple
  vim.g.terminal_color_14 = c.brightAqua
  vim.g.terminal_color_15 = c.fg1
end

return M
