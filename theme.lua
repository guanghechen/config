require("eve.option")
_G.eve = require("eve")

local storage = { client = eve.path.locate_context_filepath("client.json") } ---@type eve.t.context.storage
eve.context.set_storage(storage)
eve.context.load(storage)

local theme = vim.g.ghc_theme or "gruvbox_light" ---@type string

local uxTheme = require("fml.ux.theme")
if not vim.tbl_contains(uxTheme.themes, theme) then
  print("Unknown theme: " .. theme)
else
  uxTheme.apply_theme({
    theme = theme,
    transparency = eve.context.state.theme.transparency:snapshot(),
    persistent = true,
    filepath = eve.path.locate_theme_filepath("theme"),
  })

  eve.context.state.theme.theme:next(theme)
  eve.context.save(storage)
end
