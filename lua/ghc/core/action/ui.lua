---@class ghc.core.action.ui.context
local context = {
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
  local darken = context.repo.darken:get_snapshot()
  context.repo.darken:next(not darken)
  require("base46").toggle_theme()
end

return M
