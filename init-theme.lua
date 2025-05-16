_G.std = require("std")
_G.eve = require("eve")
eve.setup_patches()
eve.setup_workspace()
require("eve.option")

local default_storage = eve.get_default_storage() ---@type eve.context.storage
local storage = { editor = default_storage.editor } ---@type eve.context.storage
eve.setup_context(storage)

local theme = vim.env.GHC_THEME or "catppuccin-mocha" ---@type std.e.Theme

if not vim.list_contains(eve.setting.themes, theme) then
  print("Unknown theme: " .. theme)
else
  eve.context.theme.apply_theme({
    theme = theme,
    transparency = eve.context.theme.transparency:snapshot(),
    persistent = true,
  })

  eve.context.theme.theme:next(theme)
  eve.context.save(storage)
end
