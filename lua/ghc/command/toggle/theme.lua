local uxTheme = require("ghc.ux.theme")

local uuids = eve.commander.uuids ---@type eve.std.commander.uuids
local theme_cache_path = eve.path.locate_theme_filepath("theme")

---@type string[]
local themes = {
  "gruvbox_dark",
  "gruvbox_light",
  "nord_dark",
  "nord_light",
  "one_half_dark",
  "one_half_light",
}

---@param force                         ?boolean
---@return nil
local function reload_theme(force)
  local theme = eve.context.state.theme.theme:snapshot() ---@type t.eve.e.Theme
  local mode = eve.context.state.theme.mode:snapshot() ---@type t.eve.e.ThemeMode
  local transparency = eve.context.state.theme.transparency:snapshot() ---@type boolean

  if force or not eve.path.is_exist(theme_cache_path) then
    uxTheme.load_theme({
      theme = theme,
      mode = mode,
      transparency = transparency,
      persistent = true,
      filepath = theme_cache_path,
    })
  else
    dofile(theme_cache_path)
  end

  local scheme = uxTheme.get_scheme(theme, mode) ---@type t.eve.collection.theme.IScheme|nil
  if scheme ~= nil then
    uxTheme.set_term_colors(scheme)
  end
end

---@param theme                         string
---@return nil
local function toggle_theme(theme)
  local ok, scheme = pcall(fml.fn.hmr, "ghc.ux.theme.scheme." .. theme)
  if ok then
    local transparency = eve.context.state.theme.transparency:snapshot() ---@type boolean

    ---@type boolean
    local has_changed = eve.context.state.theme.theme:snapshot() ~= scheme.theme
      or eve.context.state.theme.mode:snapshot() ~= scheme.mode
    if has_changed then
      eve.context.state.theme.theme:next(scheme.theme)
      eve.context.state.theme.mode:next(scheme.mode)
    end

    if has_changed then
      uxTheme.load_theme({
        theme = scheme.theme,
        mode = scheme.mode,
        transparency = transparency,
        persistent = true,
        filepath = theme_cache_path,
      })
    end
  else
    eve.reporter.error({
      from = "ghc.command.toggle",
      subject = "theme",
      message = "Cannot find the theme.",
      details = { theme = theme, error = scheme },
    })
  end
end

eve.commander
  .register({
    uuid = uuids.reload_theme,
    desc = "reload: theme",
    nargs = "?",
    action = function(args)
      local force = type(args) == "string" and args:lower() == "true" ---@type boolean
      reload_theme(force)
    end,
  })
  .register({
    uuid = uuids.toggle_theme,
    desc = "toggle: theme",
    candidates = themes,
    nargs = "?",
    action = function(args)
      local arg = type(args) == "string" and args:lower() or "" ---@type string
      if eve.array.contains(themes, arg) then
        toggle_theme(arg)
      else
        fml.fn.select({
          title = "Select theme",
          flag_fuzzy = true,
          flag_regex = false,
          input = eve.c.Observable.from_value(arg),
          dimension = {
            row = 5,
            width = 50,
          },
          get_present = function()
            local t = eve.context.state.theme.theme:snapshot() ---@type t.eve.e.Theme
            local m = eve.context.state.theme.mode:snapshot() ---@type t.eve.e.ThemeMode
            return t .. "_" .. m
          end,
          fetch_items = function()
            local items = {} ---@type t.fml.ux.select.IItem[]
            for _, theme in ipairs(themes) do
              table.insert(items, { uuid = theme, text = theme })
            end
            return items
          end,
          on_confirm = function(item)
            local theme = item.uuid ---@type string
            toggle_theme(theme)
          end,
        })
      end
    end,
  })
