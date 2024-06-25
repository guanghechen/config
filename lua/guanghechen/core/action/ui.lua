---@class guanghechen.core.action.ui
local M = {}

function M.show_inspect_pos()
  vim.show_pos()
end

function M.show_inspect_tree()
  vim.cmd("InspectTree")
end

function M.dismiss_notifications()
  require("notify").dismiss({
    silent = true,
    pending = true,
  })
end

return M
