local uuids = eve.commander.uuids ---@type eve.std.commander.uuids
local theme_cache_path = eve.path.locate_theme_filepath("theme")

---@param force                         ?boolean
---@return nil
local function reload_theme(force)
  local theme = eve.context.state.theme.theme:snapshot() ---@type t.eve.e.Theme
  local transparency = eve.context.state.theme.transparency:snapshot() ---@type boolean

  if force or not eve.path.is_exist(theme_cache_path) then
    fml.ux.theme.apply_theme({
      theme = theme,
      transparency = transparency,
      persistent = true,
      filepath = theme_cache_path,
    })
  else
    dofile(theme_cache_path)

    local scheme = fml.ux.theme.get_scheme(theme) ---@type t.eve.collection.theme.IScheme|nil
    if scheme ~= nil then
      fml.ux.theme.set_term_colors(scheme)
    end
  end

  ---! Reload the plugins to trigger it to apply the new highlights.
  pcall(function()
    ---! Reload the indent-blankline.nvim plugin.
    vim.cmd("Lazy reload indent-blankline.nvim")
  end)
end

---@param theme                         string
---@return nil
local function apply_theme(theme)
  if not vim.tbl_contains(fml.ux.theme.themes, theme) then
    eve.reporter.error({
      from = "ghc.command.toggle",
      subject = "theme",
      message = "Unknown theme.",
      details = { theme = theme },
    })
    return
  end

  local app_home = eve.path.locate_app_config_home("guanghechen")
  local script_path = eve.path.join(app_home, "config/theme/apply_theme.mjs")
  local ok, error = pcall(function()
    vim.fn.system({ "node", script_path, theme })
  end)
  if not ok then
    eve.reporter.error({
      from = "ghc.command.toggle",
      subject = "theme",
      message = "Failed to toggle theme.",
      details = { theme = theme, app_home = app_home, script_path = script_path, error = error },
    })
  end
end

---@param theme                         string
---@return nil
local function toggle_theme_variant(theme)
  local app_home = eve.path.locate_app_config_home("guanghechen")
  local script_path = eve.path.join(app_home, "config/theme/toggle_theme.mjs")
  local ok, error = pcall(function()
    vim.fn.system({ "node", script_path, theme })
  end)
  if not ok then
    eve.reporter.error({
      from = "ghc.command.toggle",
      subject = "theme variant",
      message = "Failed to toggle theme variant.",
      details = { theme = theme, app_home = app_home, script_path = script_path, error = error },
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
        apply_theme(arg)
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
            local theme = eve.context.state.theme.theme:snapshot() ---@type t.eve.e.Theme
            return theme
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
            apply_theme(theme)
          end,
        })
      end
    end,
  })
  .register({
    uuid = uuids.toggle_theme_variant,
    desc = "toggle: theme variant",
    action = function()
      local theme = eve.context.state.theme.theme:snapshot() ---@type t.eve.e.Theme
      toggle_theme_variant(theme)
    end,
  })
