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
  require("base46").load_all_highlights()
end

function M.toggle_theme()
  ---@type boolean
  local darken = context.global.darken:get_snapshot()
  context.global.darken:next(not darken)

  vim.g.icon_toggled = not vim.g.icon_toggled
  vim.g.toggle_theme_icon = vim.g.icon_toggled and "   " or "   "

  ---@type boolean
  local is_darken = context.global.darken:get_snapshot()
  ---@type string
  local theme_lighten = context.global.theme_lighten:get_snapshot()
  ---@type string
  local theme_darken = context.global.theme_darken:get_snapshot()

  require("nvconfig").ui.theme = is_darken and theme_darken or theme_lighten

  require("base46").load_all_highlights()
end

function M.toggle_relative_line_number()
  ---@type boolean
  local next_relativenumber = not context.global.relativenumber:get_snapshot()
  context.global.relativenumber:next(next_relativenumber)
  vim.opt.relativenumber = next_relativenumber
end

return M
