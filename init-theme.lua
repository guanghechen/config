require("bot").setup()

_G.ark = require("ark") ---@type ark
_G.dot = require("dot") ---@type dot
_G.era = require("era") ---@type era
_G.ux = require("ux") ---@type ux

local default_storage = era.get_default_storage() ---@type era.context.storage
local storage = { editor = default_storage.editor } ---@type era.context.storage
era.setup_context(storage)

local theme = vim.env.GHC_THEME or "catppuccin-mocha" ---@type dot.e.ThemeFullName

if not vim.list_contains(dot.var.theme, theme) then
  print("Unknown theme: " .. theme)
else
  era.context.theme.apply_theme({
    theme = theme,
    transparency = era.context.theme.transparency:snapshot(),
    persistent = true,
  })

  era.context.theme.theme:next(theme)
  era.context.save(storage)
end
