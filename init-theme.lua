_G.yoz = require("yoz") ---@type yoz
_G.ark = require("ark") ---@type ark
_G.dot = require("dot") ---@type dot
require("dot.bootstrap").setup()

_G.era = require("era") ---@type era
_G.std = require("std") ---@type std
_G.eve = require("eve") ---@type eve
_G.ux = require("ux") ---@type ux

local default_storage = eve.get_default_storage() ---@type eve.context.storage
local storage = { editor = default_storage.editor } ---@type eve.context.storage
eve.setup_context(storage)

local theme = vim.env.GHC_THEME or "catppuccin-mocha" ---@type dot.e.ThemeFullName

if not vim.list_contains(dot.var.theme, theme) then
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
