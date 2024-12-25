_G.eve = require("eve")
eve.setup_workspace()
require("eve.option")

local path = require("eve.lib.path")
local storage = { editor = path.locate_context_filepath("editor.json") } ---@type eve.state.storage
eve.setup_state(storage)

local themes = require("eve.theme").themes ---@type eve.e.Theme[]
local theme = vim.g.ghc_theme or "gruvbox_light" ---@type eve.e.Theme

if not vim.tbl_contains(themes, theme) then
  print("Unknown theme: " .. theme)
else
  local state = require("eve.state")
  require("eve.theme").apply_theme({
    theme = theme,
    transparency = state.theme.transparency:snapshot(),
    persistent = true,
    filepath = path.locate_context_filepath("theme"),
  })

  state.theme.theme:next(theme)
  state.save(storage)
end
