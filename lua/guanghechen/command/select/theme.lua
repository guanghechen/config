local uuids = eve.commander.uuids

---@type string[]
local themes = {
  "gruvbox_dark",
  "gruvbox_light",
  "one_half_dark",
  "one_half_light",
}

---@param theme                         string
---@return nil
local function toggle_theme(theme)
  local ok, scheme = pcall(fml.fn.hmr, "ghc.ux.theme.scheme." .. theme)
  if ok then
    ---@cast scheme t.fml.ux.theme.IScheme
    ghc.action.theme.toggle_scheme({
      mode = scheme.mode,
      theme = scheme.theme,
      persistent = true,
      force = false,
    })
  else
    eve.reporter.error({
      from = "ghc.action.theme",
      subject = "select_theme",
      message = "Failed to load theme scheme",
      details = { theme = theme, error = scheme },
    })
  end
end

eve.commander.register({
  uuid = uuids.select_theme,
  desc = "select: theme",
  candidates = themes,
  nargs = "?",
  action = function(args)
    local arg = type(args) == "string" and args:lower() or ""

    if eve.array.contains(themes, arg) then
      toggle_theme(arg)
    else
      fml.fn.select({
        title = "Select theme",
        input = eve.c.Observable.from_value(arg),
        dimension = {
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
