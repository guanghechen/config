require("bot").setup()

_G.ark = require("ark") ---@type ark
_G.dot = require("dot") ---@type dot
_G.ux = require("ux") ---@type ux

local default_storage = dot.get_default_storage() ---@type dot.context.storage
local storage = { editor = default_storage.editor } ---@type dot.context.storage
dot.setup_context(storage)

local theme = vim.env.GHC_THEME or "catppuccin-mocha" ---@type dot.e.ThemeFullName

if not vim.list_contains(dot.var.theme, theme) then
  print("Unknown theme: " .. theme)
else
  dot.context.theme.apply_theme({
    theme = theme,
    transparency = dot.context.theme.transparency:snapshot(),
    persistent = true,
  })

  dot.context.theme.theme:next(theme)
  dot.context.save(storage)
end
