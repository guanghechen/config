local uuids = eve.commander.uuids ---@type eve.std.commander.uuids
local theme_cache_path = eve.path.locate_theme_filepath("theme")

---@param force                         ?boolean
---@return nil
local function reload_theme(force)
  local theme = eve.context.state.theme.theme:snapshot() ---@type t.eve.e.Theme
  local mode = eve.context.state.theme.mode:snapshot() ---@type t.eve.e.ThemeMode
  local transparency = eve.context.state.theme.transparency:snapshot() ---@type boolean

  if force or not eve.path.is_exist(theme_cache_path) then
    fml.ux.theme.load_theme({
      theme = theme,
      mode = mode,
      transparency = transparency,
      persistent = true,
      filepath = theme_cache_path,
    })
  else
    dofile(theme_cache_path)
  end

  local scheme = fml.ux.theme.get_scheme(theme, mode) ---@type t.eve.collection.theme.IScheme|nil
  if scheme ~= nil then
    fml.ux.theme.set_term_colors(scheme)
  end
end

---@param theme                         string
---@return nil
local function toggle_theme(theme)
  if not vim.tbl_contains(fml.ux.theme.themes, theme) then
    eve.reporter.error({
      from = "ghc.command.toggle",
      subject = "theme",
      message = "Unknown theme.",
      details = { theme = theme },
    })
    return
  end

  local ok, scheme = pcall(eve.fn.hmr, "fml.ux.theme.scheme." .. theme)
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
      fml.ux.theme.load_theme({
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
      local force = type(args) == "string" and args:lower() == "force" ---@type boolean
      reload_theme(force)
    end,
  })
  .register({
    uuid = uuids.toggle_theme,
    desc = "toggle: theme",
    candidates = fml.ux.theme.themes,
    nargs = "?",
    action = function(args)
      local arg = type(args) == "string" and args:lower() or "" ---@type string
      if vim.tbl_contains(fml.ux.theme.themes, arg) then
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
            for _, theme in ipairs(fml.ux.theme.themes) do
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
