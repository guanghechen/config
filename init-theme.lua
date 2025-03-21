_G.eve = require("eve")
eve.setup_patches()
eve.setup_workspace()
require("eve.option")

local default_storage = eve.get_default_storage() ---@type eve.state.storage
local storage = { editor = default_storage.editor } ---@type eve.state.storage
eve.setup_state(storage)

local theme = vim.env.GHC_THEME or "catppuccin-mocha" ---@type eve.e.Theme

if not vim.list_contains(eve.setting.themes, theme) then
  print("Unknown theme: " .. theme)
else
  eve.state.theme.apply_theme({
    theme = theme,
    transparency = eve.state.theme.transparency:snapshot(),
    persistent = true,
  })

  eve.state.theme.theme:next(theme)
  eve.state.save(storage)
end
