_G.eve = require("eve")
eve.setup_patches()
eve.setup_workspace()
require("eve.option")

local default_storage = eve.get_default_storage() ---@type eve.state.storage
local storage = { editor = default_storage.editor } ---@type eve.state.storage
eve.setup_state(storage)

local theme = vim.env.GHC_THEME or "gruvbox-dark" ---@type eve.e.Theme

if not vim.list_contains(eve.setting.themes, theme) then
  print("Unknown theme: " .. theme)
else
  local state = require("eve.state")
  state.theme.apply_theme({
    theme = theme,
    transparency = state.theme.transparency:snapshot(),
    persistent = true,
  })

  state.theme.theme:next(theme)
  state.save(storage)
end
