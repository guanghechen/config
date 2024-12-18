local path = require("eve.lib.path")
local state = require("eve.state")

require("eve.setup").workspace()

---@type eve.state.storage
local storage = {
  editor = path.locate_context_filepath("editor.json"),
}

state.set_storage(storage)
state.load(storage)

require("eve.option")
_G.eve = require("eve")

local theme = vim.g.ghc_theme or "gruvbox_light" ---@type string

local uxTheme = require("fml.ux.theme")
if not vim.tbl_contains(uxTheme.themes, theme) then
  print("Unknown theme: " .. theme)
else
  uxTheme.apply_theme({
    theme = theme,
    transparency = state.theme.transparency:snapshot(),
    persistent = true,
    filepath = path.locate_context_filepath("theme"),
  })

  state.theme.theme:next(theme)
  state.save(storage)
end
