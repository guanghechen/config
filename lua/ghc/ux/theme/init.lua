---@class ghc.ux.theme
local M = {}

---@class ghc.ux.theme.ILoadThemeParams
---@field public theme                  t.eve.e.Theme
---@field public mode                   t.eve.e.ThemeMode
---@field public transparency           boolean
---@field public persistent             boolean
---@field public filepath               ?string
---@field public nsnr                   ?integer

---@type t.ghc.e.ux.theme.HighlightIntegration[]
M.integrations = {
  --- orders as needed
  "basic",
  "statusline",
  "tabline",
  "winline",

  "widget",
  "treesitter",
  "plugin",
}

---@param scheme                        t.fml.ux.theme.IScheme
---@return nil
function M.set_term_colors(scheme)
  local c = scheme.palette ---@type t.fml.ux.theme.IPalette
  vim.g.terminal_color_0 = c.bg0
  vim.g.terminal_color_1 = c.neutral_red
  vim.g.terminal_color_2 = c.neutral_green
  vim.g.terminal_color_3 = c.neutral_yellow
  vim.g.terminal_color_4 = c.neutral_blue
  vim.g.terminal_color_5 = c.neutral_purple
  vim.g.terminal_color_6 = c.neutral_aqua
  vim.g.terminal_color_7 = c.fg4
  vim.g.terminal_color_8 = c.grey
  vim.g.terminal_color_9 = c.red
  vim.g.terminal_color_10 = c.green
  vim.g.terminal_color_11 = c.yellow
  vim.g.terminal_color_12 = c.blue
  vim.g.terminal_color_13 = c.purple
  vim.g.terminal_color_14 = c.aqua
  vim.g.terminal_color_15 = c.fg1
end

---@param theme                         t.eve.e.Theme
---@param mode                          t.eve.e.ThemeMode
---@return t.fml.ux.theme.IScheme|nil
function M.get_scheme(theme, mode)
  local scheme_name = theme .. "_" .. mode
  local ok, scheme = pcall(fml.fn.hmr, "ghc.ux.theme.scheme." .. scheme_name)
  if not ok then
    eve.reporter.error({
      from = "ghc.ux.theme",
      subject = "get_scheme",
      message = "Cannot find scheme.",
      details = { theme = theme, mode = mode },
    })
    return nil
  end
  return scheme
end

---@param nsnr                          integer
---@param integration                   t.ghc.e.ux.theme.HighlightIntegration
---@return nil
function M.load_integration(nsnr, integration)
  local theme = eve.context.state.theme.theme:snapshot() ---@type t.eve.e.Theme
  local mode = eve.context.state.theme.mode:snapshot() ---@type t.eve.e.ThemeMode
  local transparency = eve.context.state.theme.transparency:snapshot() ---@type boolean

  local scheme = M.get_scheme(theme, mode)
  if scheme ~= nil then
    ---@type t.ghc.ux.IThemeContext
    local context = {
      theme = scheme.theme .. "_" .. scheme.mode,
      scheme = scheme,
      transparency = transparency,
    }
    local gen_hlgroup_map = fml.fn.hmr("ghc.ux.theme.integration." .. integration)
    local hlgroup_map = gen_hlgroup_map(context)
    local uxTheme = fml.ux.Theme.new()
    uxTheme:registers(hlgroup_map)
    uxTheme:apply({ nsnr = nsnr, scheme = scheme })
  end
end

---@param params                        ghc.ux.theme.ILoadThemeParams
---@return t.fml.ux.theme.IScheme|nil
function M.load_theme(params)
  local theme = params.theme ---@type t.eve.e.Theme
  local mode = params.mode ---@type t.eve.e.ThemeMode
  local transparency = params.transparency ---@type boolean
  local persistent = params.persistent ---@type boolean
  local filepath = params.filepath ---@type string|nil
  local nsnr = params.nsnr or 0 ---@type integer

  local scheme = M.get_scheme(theme, mode)
  if scheme ~= nil then
    local gen_tabline_hlgroup_map = fml.fn.hmr("ghc.ux.theme.integration.tabline")
    local gen_winline_hlgroup_map = fml.fn.hmr("ghc.ux.theme.integration.winline")

    ---@type ghc.ux.theme.integration.tabline.hlgroups
    local tabline_hlgroup_map = gen_tabline_hlgroup_map({ scheme = scheme, transparency = transparency })

    ---@type ghc.ux.theme.integration.winline.hlgroups
    local winline_hlgroup_map = gen_winline_hlgroup_map({ scheme = scheme, transparency = transparency })

    local uxTheme = fml.ux.Theme.new()
    for _, integration in ipairs(M.integrations) do
      local gen_hlgroup_map = fml.fn.hmr("ghc.ux.theme.integration." .. integration)
      ---@return table<string, t.fml.ux.theme.IHlgroup>
      local hlgroup_map = gen_hlgroup_map({ scheme = scheme, transparency = transparency })

      if integration == "plugin" then
        local additional = {} ---@type table<string, t.fml.ux.theme.IHlgroup>
        for hlname, hlgroup in pairs(hlgroup_map) do
          if hlname:sub(1, 9) == "MiniIcons" then
            ---! Integrated  with tabline
            additional[hlname .. "_tl_buf"] = { fg = hlgroup.fg, bg = tabline_hlgroup_map.f_tl_buf_item.bg }
            additional[hlname .. "_tl_buf_cur"] = { fg = hlgroup.fg, bg = tabline_hlgroup_map.f_tl_buf_item_cur.bg }

            ---! Integrated  with winline
            additional[hlname .. "_wl"] = { fg = hlgroup.fg, bg = winline_hlgroup_map.f_wl_bg.bg }
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
      vim.schedule(function()
        uxTheme:compile({ nsnr = 0, scheme = scheme, filepath = filepath })
      end)
    end
    M.set_term_colors(scheme)

    ---! toggle theme for other apps.
    do
      local app_home = eve.path.locate_app_config_home("guanghechen")
      local script_path = eve.path.join(app_home, "config/theme/apply_theme.mjs")
      local ok, error = pcall(function()
        vim.fn.system({ "node", script_path, theme .. "_" .. mode })
      end)
      if not ok then
        eve.reporter.error({
          from = "ghc.ux.theme",
          subject = "load_theme",
          message = "Failed to toggle theme.",
          details = { app_home = app_home, script_path = script_path, error = error },
        })
      end
    end
  end

  return scheme
end

return M
