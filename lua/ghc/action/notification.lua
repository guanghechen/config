---@class ghc.action.notification
local M = {}

function M.dismiss_all()
  require("notify").dismiss({
    silent = true,
    pending = true,
  })
end

return M
