_G.eve = require("eve")
eve.setup_workspace()
require("eve.option")

local default_storage = eve.get_default_storage() ---@type eve.state.storage
local storage = { editor = default_storage.editor } ---@type eve.state.storage
eve.setup_state(storage)

local themes = require("eve.theme").themes ---@type eve.e.Theme[]
local theme = vim.env.GHC_THEME or "gruvbox_dark" ---@type eve.e.Theme

if not vim.tbl_contains(themes, theme) then
  print("Unknown theme: " .. theme)
else
  local state = require("eve.state")
  require("eve.theme").apply_theme({
    theme = theme,
    transparency = state.theme.transparency:snapshot(),
    persistent = true,
    filepath = require("eve.theme").cache_path,
  })

  state.theme.theme:next(theme)
  state.save(storage)
end
