require("eve.option")
_G.eve = require("eve")

local storage = { client = eve.path.locate_context_filepath("client.json") } ---@type t.eve.context.storage
eve.context.set_storage(storage)
eve.context.load(storage)

local theme_name = vim.g.ghc_theme or "gruvbox_light" ---@type string

local uxTheme = require("fml.ux.theme")
if not vim.tbl_contains(uxTheme.themes, theme_name) then
  print("Unknown theme: " .. theme_name)
else
  local theme, mode = theme_name:match("^(.*)_([^_]+)$") ---@type string, string

  uxTheme.apply_theme({
    theme = theme,
    mode = mode,
    transparency = eve.context.state.theme.transparency:snapshot(),
    persistent = true,
    filepath = eve.path.locate_theme_filepath("theme"),
  })

  eve.context.state.theme.theme:next(theme)
  eve.context.state.theme.mode:next(mode)
  eve.context.save(storage)
end
