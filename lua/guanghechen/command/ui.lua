---@class guanghechen.command.ui
local M = {}

function M.dismiss_notifications()
  require("notify").dismiss({
    silent = true,
    pending = true,
  })
end

return M
