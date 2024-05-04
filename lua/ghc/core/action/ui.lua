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

function M.toggle_theme()
  require("base46").toggle_theme()
end

return M
