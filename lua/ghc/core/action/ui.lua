---@class ghc.core.action.ui.context
local context = {
  global = require("ghc.core.context.global"),
  repo = require("ghc.core.context.repo"),
}

---@class ghc.core.action.ui
local M = {}

function M.show_inspect_pos()
  vim.show_pos()
end

function M.dismiss_notifications()
  require("notify").dismiss({
    silent = true,
    pending = true,
  })
end

function M.toggle_transparency()
  context.repo.transparency:next(not context.repo.transparency:get_snapshot())
  require("base46").toggle_transparency()
end

function M.toggle_theme()
  ---@type boolean
  local darken = context.global.darken:get_snapshot()
  context.global.darken:next(not darken)

  vim.g.icon_toggled = not vim.g.icon_toggled
  vim.g.toggle_theme_icon = vim.g.icon_toggled and "   " or "   "

  require("base46").load_all_highlights()
end

return M
