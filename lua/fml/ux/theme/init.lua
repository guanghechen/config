local __module_name__ = "fml.ux.theme" ---@type string

local Theme = require("eve.lib.collection.theme")
local reporter = require("eve.lib.reporter")
local hmr = require("eve.fn.hmr")

---@class fml.ux.theme
local M = {}

---@class fml.t.ux.IThemeContext
---@field public theme                  string
---@field public scheme                 eve.lib.collection.theme.IScheme
---@field public transparency           boolean

---@class fml.t.ux.theme.IApp
---@field public get_filepaths          fun(context: fml.t.ux.IThemeContext): string[]
---@field public gen_theme              fun(context: fml.t.ux.IThemeContext): string
---@field public after_written          ?fun(context: fml.t.ux.IThemeContext): nil

---@alias fml.e.ux.theme.HighlightIntegration
---|"basic"
---|"nvimbar"
---|"widget"
---|"treesitter"
---|"plugin"

---@class fml.ux.theme.ILoadIntegrationParams
---@field public theme                  eve.e.Theme
---@field public transparency           boolean
---@field public integration            fml.e.ux.theme.HighlightIntegration
---@field public nsnr                   ?integer

---@class fml.ux.theme.ILoadThemeParams
---@field public theme                  eve.e.Theme
---@field public transparency           boolean
---@field public persistent             boolean
---@field public filepath               ?string
---@field public nsnr                   ?integer

---@type eve.e.Theme[]
M.themes = {
  "catppuccin-latte",
  "catppuccin-mocha",
  "gruvbox_dark",
  "gruvbox_light",
  "nord",
  "one_half_dark",
  "one_half_light",
}

---@type fml.e.ux.theme.HighlightIntegration[]
M.integrations = {
  --- orders as needed
  "basic",
  "nvimbar",
  "widget",
  "treesitter",
  "plugin",
}

---@param scheme                        eve.lib.collection.theme.IScheme
---@return nil
function M.set_term_colors(scheme)
  local c = scheme.palette ---@type eve.lib.collection.theme.IPalette
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

---@param theme                         eve.e.Theme
---@return eve.lib.collection.theme.IScheme|nil
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

  local ok, scheme = pcall(hmr, "fml.ux.theme.scheme." .. theme)
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

---@param params                        fml.ux.theme.ILoadIntegrationParams
---@return nil
function M.apply_integration(params)
  local theme = params.theme ---@type eve.e.Theme
  local transparency = params.transparency ---@type boolean
  local integration = params.integration ---@type fml.e.ux.theme.HighlightIntegration
  local nsnr = params.nsnr or 0 ---@type integer

  local scheme = M.get_scheme(theme)
  if scheme ~= nil then
    ---@type fml.t.ux.IThemeContext
    local themeContext = {
      theme = scheme.theme,
      scheme = scheme,
      transparency = transparency,
    }
    local gen_hlgroup_map = hmr("fml.ux.theme.integration." .. integration)
    local hlgroup_map = gen_hlgroup_map(themeContext)
    local uxTheme = Theme.new()
    uxTheme:registers(hlgroup_map)
    uxTheme:apply({ nsnr = nsnr, scheme = scheme })
  end
end

---@param params                        fml.ux.theme.ILoadThemeParams
---@return eve.lib.collection.theme.IScheme|nil
function M.apply_theme(params)
  local theme = params.theme ---@type eve.e.Theme
  local transparency = params.transparency ---@type boolean
  local persistent = params.persistent ---@type boolean
  local filepath = params.filepath ---@type string|nil
  local nsnr = params.nsnr or 0 ---@type integer

  local scheme = M.get_scheme(theme)
  if scheme ~= nil then
    local gen_nvimbar_hlgroup_map = hmr("fml.ux.theme.integration.nvimbar")

    ---@type fml.ux.theme.integration.nvimbar.hlgroups
    local nvimbar_hlgroup_map = gen_nvimbar_hlgroup_map({ scheme = scheme, transparency = transparency })

    local uxTheme = Theme.new()
    for _, integration in ipairs(M.integrations) do
      local gen_hlgroup_map = hmr("fml.ux.theme.integration." .. integration)
      ---@return table<string, eve.lib.collection.theme.IHlgroup>
      local hlgroup_map = gen_hlgroup_map({ scheme = scheme, transparency = transparency })

      if integration == "plugin" then
        local additional = {} ---@type table<string, eve.lib.collection.theme.IHlgroup>
        for hlname, hlgroup in pairs(hlgroup_map) do
          if hlname:sub(1, 9) == "MiniIcons" then
            additional["f_sl_" .. hlname] = { fg = hlgroup.fg, bg = nvimbar_hlgroup_map.f_sl_bg.bg }
            additional["f_tl_" .. hlname] = { fg = hlgroup.fg, bg = nvimbar_hlgroup_map.f_tl_bg.bg }
            additional["f_wl_" .. hlname] = { fg = hlgroup.fg, bg = nvimbar_hlgroup_map.f_wl_bg.bg }

            additional["f_sl_buf_" .. hlname] = { fg = hlgroup.fg, bg = nvimbar_hlgroup_map.f_sl_buf.bg }
            additional["f_tl_buf_" .. hlname] = { fg = hlgroup.fg, bg = nvimbar_hlgroup_map.f_tl_buf.bg }
            additional["f_wl_buf_" .. hlname] = { fg = hlgroup.fg, bg = nvimbar_hlgroup_map.f_wl_buf.bg }

            additional["f_sl_buf_cur_" .. hlname] = { fg = hlgroup.fg, bg = nvimbar_hlgroup_map.f_sl_buf_cur.bg }
            additional["f_tl_buf_cur_" .. hlname] = { fg = hlgroup.fg, bg = nvimbar_hlgroup_map.f_tl_buf_cur.bg }
            additional["f_wl_buf_cur_" .. hlname] = { fg = hlgroup.fg, bg = nvimbar_hlgroup_map.f_wl_buf_cur.bg }

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

return M
