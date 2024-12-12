local __module_name__ = "ghc.command.toggle.theme" ---@type string

local path = require("eve.lib.path")
local reporter = require("eve.lib.reporter")
local Observable = require("eve.lib.collection.observable")
local state = require("eve.state")

local uuids = eve.commander.uuids ---@type eve.builtin.commander.uuids
local theme_cache_path = path.locate_context_filepath("theme")

---@param force                         ?boolean
---@return nil
local function reload_theme(force)
  local theme = state.state.theme.theme:snapshot() ---@type eve.e.Theme
  local transparency = state.state.theme.transparency:snapshot() ---@type boolean

  if force or not path.is_exist(theme_cache_path) then
    fml.ux.theme.apply_theme({
      theme = theme,
      transparency = transparency,
      persistent = true,
      filepath = theme_cache_path,
    })
  else
    dofile(theme_cache_path)

    local scheme = fml.ux.theme.get_scheme(theme) ---@type eve.lib.collection.theme.IScheme|nil
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
    reporter.error({
      from = __module_name__,
      subject = "apply_theme",
      message = "Unknown theme.",
      details = { theme = theme },
    })
    return
  end

  local app_home = path.locate_app_config_home("guanghechen")
  local script_path = path.join(app_home, "config/theme/apply_theme.mjs")
  local ok, error = pcall(function()
    vim.fn.system({ "node", script_path, theme })
  end)
  if not ok then
    reporter.error({
      from = __module_name__,
      subject = "apply_theme",
      message = "Failed to toggle theme.",
      details = { theme = theme, app_home = app_home, script_path = script_path, error = error },
    })
  end
end

---@param theme                         string
---@return nil
local function toggle_theme_variant(theme)
  local app_home = path.locate_app_config_home("guanghechen")
  local script_path = path.join(app_home, "config/theme/toggle_theme.mjs")
  local ok, error = pcall(function()
    vim.fn.system({ "node", script_path, theme })
  end)
  if not ok then
    reporter.error({
      from = __module_name__,
      subject = "toggle_theme_variant",
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
          input = Observable.from_value(arg),
          dimension = {
            row = 5,
            width = 50,
          },
          get_present = function()
            local theme = state.state.theme.theme:snapshot() ---@type eve.e.Theme
            return theme
          end,
          fetch_items = function()
            local items = {} ---@type fml.t.ux.select.IItem[]
            for _, theme in ipairs(fml.ux.theme.themes) do
              items[#items + 1] = { uuid = theme, text = theme }
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
      local theme = state.state.theme.theme:snapshot() ---@type eve.e.Theme
      toggle_theme_variant(theme)
    end,
  })
