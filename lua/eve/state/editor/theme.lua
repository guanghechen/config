local __module_name__ = "eve.state.editor.theme" ---@type string

---@class eve.theme.ILoadIntegrationParams
---@field public theme                  eve.e.Theme
---@field public transparency           boolean
---@field public integration            eve.e.ThemeIntegration
---@field public nsnr                   ?integer

---@class eve.theme.ILoadThemeParams
---@field public theme                  eve.e.Theme
---@field public transparency           boolean
---@field public persistent             boolean
---@field public nsnr                   ?integer

---@class eve.state.theme.data
---@field public theme                  eve.e.Theme
---@field public transparency           boolean
---@field public username               boolean

---@class eve.state.theme.state
---@field public theme                  eve.collection.IObservable -- eve.e.Theme>
---@field public transparency           eve.collection.IObservable -- boolean>
---@field public username               eve.collection.IObservable -- boolean>
---
---@field public apply_integration      fun(params: eve.theme.ILoadIntegrationParams): nil
---@field public apply_theme            fun(params: eve.theme.ILoadThemeParams): nil
---@field public get_scheme             fun(theme: eve.e.Theme): eve.t.theme.IScheme | nil
---@field public reload_theme           fun(force: boolean, reload_plugins: boolean): nil
---@field public set_term_colors        fun(scheme: eve.t.theme.IScheme): nil

---@class eve.state.theme
---@field public defaults               fun(): eve.state.theme.data
---@field public dump                   fun(): eve.state.theme.data
---@field public load                   fun(data: unknown): eve.state.theme.state
---@field public normalize              fun(data: unknown): eve.state.theme.data
local M = {}

local _state = nil ---@type eve.state.theme.state | nil

---@type eve.e.ThemeIntegration[]
local integrations = {
  "basic",
  "nvimbar",
  "widget",
  "treesitter",
  "plugin",
}

---@return string
local function get_theme_path()
  return eve.path.locate_context_filepath("theme")
end

---@return eve.state.theme.data
function M.defaults()
  ---@type eve.state.theme.data
  return {
    theme = "gruvbox-dark",
    transparency = false,
    username = true,
  }
end

---@param data                        any
---@return eve.state.theme.data
function M.normalize(data)
  local resolved = M.defaults() ---@type eve.state.theme.data
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

  ---@type eve.state.theme.data
  return resolved
end

---@return eve.state.theme.data
function M.dump()
  if _state == nil then
    ---@type eve.state.theme.data
    return M.defaults()
  end

  ---@type eve.state.theme.data
  return {
    theme = _state.theme:snapshot(),
    transparency = _state.transparency:snapshot(),
    username = _state.username:snapshot(),
  }
end

---@param raw_data                      any
---@return eve.state.theme.state
function M.load(raw_data)
  local data = M.normalize(raw_data) ---@type eve.state.theme.data
  if _state == nil then
    ---@cast _state eve.state.theme.state

    ---@type eve.state.theme.state
    _state = {
      theme = eve.col.Observable.from_value(data.theme),
      transparency = eve.col.Observable.from_value(data.transparency),
      username = eve.col.Observable.from_value(data.username),

      apply_integration = function(params)
        local theme = params.theme ---@type eve.e.Theme
        local transparency = params.transparency ---@type boolean
        local integration = params.integration ---@type eve.e.ThemeIntegration
        local nsnr = params.nsnr or 0 ---@type integer

        local scheme = _state.get_scheme(theme)
        if scheme ~= nil then
          ---@type eve.t.theme.IContext
          local themeContext = {
            theme = scheme.theme,
            scheme = scheme,
            transparency = transparency,
          }
          local gen_hlgroup_map = require("eve.constant.hlgroup." .. integration)
          local hlgroup_map = gen_hlgroup_map(themeContext)
          local uxTheme = eve.col.Theme.new()
          uxTheme:registers(hlgroup_map)
          uxTheme:apply({ nsnr = nsnr, scheme = scheme })
        end
      end,

      apply_theme = function(params)
        local theme = params.theme ---@type eve.e.Theme
        local transparency = params.transparency ---@type boolean
        local persistent = params.persistent ---@type boolean
        local nsnr = params.nsnr or 0 ---@type integer

        local scheme = _state.get_scheme(theme)
        if scheme ~= nil then
          local gen_nvimbar_hlgroup_map = require("eve.constant.hlgroup.nvimbar")

          ---@type eve.constant.hlgroup.nvimbar
          local nvimbar_hlgroup_map = gen_nvimbar_hlgroup_map({
            theme = theme,
            scheme = scheme,
            transparency = transparency,
          })

          local uxTheme = eve.col.Theme.new()
          for _, integration in ipairs(integrations) do
            local gen_hlgroup_map = require("eve.constant.hlgroup." .. integration)
            ---@return table<string, eve.t.theme.IHlgroup>
            local hlgroup_map = gen_hlgroup_map({ scheme = scheme, transparency = transparency })

            if integration == "plugin" then
              local additional = {} ---@type table<string, eve.t.theme.IHlgroup>
              for hlname, hlgroup in pairs(hlgroup_map) do
                if hlname:sub(1, 9) == "MiniIcons" then
                  additional["f_sl_" .. hlname] = { fg = hlgroup.fg, bg = nvimbar_hlgroup_map.f_sl_bg.bg }
                  additional["f_tl_" .. hlname] = { fg = hlgroup.fg, bg = nvimbar_hlgroup_map.f_tl_bg.bg }
                  additional["f_wl_" .. hlname] = { fg = hlgroup.fg, bg = nvimbar_hlgroup_map.f_wl_bg.bg }

                  additional["f_sl_buf_" .. hlname] = { fg = hlgroup.fg, bg = nvimbar_hlgroup_map.f_sl_buf.bg }
                  additional["f_tl_buf_" .. hlname] = { fg = hlgroup.fg, bg = nvimbar_hlgroup_map.f_tl_buf.bg }
                  additional["f_wl_buf_" .. hlname] = { fg = hlgroup.fg, bg = nvimbar_hlgroup_map.f_wl_buf.bg }

                  additional["f_sl_bufc_" .. hlname] = {
                    fg = hlgroup.fg,
                    bg = nvimbar_hlgroup_map.f_sl_bufc.bg,
                    underline = true,
                    sp = nvimbar_hlgroup_map.f_sl_bufc.sp,
                  }
                  additional["f_tl_bufc_" .. hlname] = {
                    fg = hlgroup.fg,
                    bg = nvimbar_hlgroup_map.f_tl_bufc.bg,
                    underline = true,
                    sp = nvimbar_hlgroup_map.f_tl_bufc.sp,
                  }
                  additional["f_wl_bufc_" .. hlname] = {
                    fg = hlgroup.fg,
                    bg = nvimbar_hlgroup_map.f_wl_bufc.bg,
                    underline = true,
                    sp = nvimbar_hlgroup_map.f_wl_bufc.sp,
                  }

                  additional["f_sl_filename_" .. hlname] =
                    { fg = hlgroup.fg, bg = nvimbar_hlgroup_map.f_sl_filename.bg }
                  additional["f_tl_filename_" .. hlname] =
                    { fg = hlgroup.fg, bg = nvimbar_hlgroup_map.f_tl_filename.bg }
                  additional["f_wl_filename_" .. hlname] =
                    { fg = hlgroup.fg, bg = nvimbar_hlgroup_map.f_wl_filename.bg }
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
          _state.set_term_colors(scheme)
        end

        return scheme
      end,

      get_scheme = function(theme)
        if not vim.list_contains(eve.setting.themes, theme) then
          eve.reporter.error({
            from = __module_name__,
            subject = "get_scheme",
            message = "Unknown theme.",
            details = { theme = theme },
          })
          return nil
        end
        return require("eve.constant.theme." .. theme)
      end,

      reload_theme = function(force, reload_plugins)
        local theme = _state.theme:snapshot() ---@type eve.e.Theme
        local transparency = _state.transparency:snapshot() ---@type boolean

        local theme_path = get_theme_path() ---@type string
        if force or not eve.path.is_exist(theme_path) then
          _state.apply_theme({
            theme = theme,
            transparency = transparency,
            persistent = true,
            filepath = theme_path,
          })
        else
          dofile(theme_path)

          local scheme = _state.get_scheme(theme) ---@type eve.t.theme.IScheme|nil
          if scheme ~= nil then
            _state.set_term_colors(scheme)
          end
        end

        ---! Reload the plugins to trigger it to apply the new highlights.
        if reload_plugins then
          pcall(function()
            vim.cmd("Lazy reload indent-blankline.nvim")
          end)
        end
      end,

      --- Set the term color with the specific value (hex).
      --- Since we also changed the terminal color outside, so no need to set it again,
      --- so we can get the terminal color automatically changed by the terminal itself
      --- since we used the color name instead of a specific value (hex).
      ---@diagnostic disable-next-line: unused-local
      set_term_colors = function(scheme)

        -- local c = scheme.palette ---@type eve.t.theme.IPalette
        -- vim.g.terminal_color_0 = c.bg0
        -- vim.g.terminal_color_1 = c.red
        -- vim.g.terminal_color_2 = c.green
        -- vim.g.terminal_color_3 = c.yellow
        -- vim.g.terminal_color_4 = c.blue
        -- vim.g.terminal_color_5 = c.purple
        -- vim.g.terminal_color_6 = c.aqua
        -- vim.g.terminal_color_7 = c.fg1
        -- vim.g.terminal_color_8 = c.bg0
        -- vim.g.terminal_color_9 = c.brightRed
        -- vim.g.terminal_color_10 = c.brightGreen
        -- vim.g.terminal_color_11 = c.brightYellow
        -- vim.g.terminal_color_12 = c.brightBlue
        -- vim.g.terminal_color_13 = c.brightPurple
        -- vim.g.terminal_color_14 = c.brightAqua
        -- vim.g.terminal_color_15 = c.fg1
      end,
    }
    return _state
  end

  _state.theme:next(data.theme)
  _state.transparency:next(data.transparency)
  _state.username:next(data.username)
  return _state
end

return M
