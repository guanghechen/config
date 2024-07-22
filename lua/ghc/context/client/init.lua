---@class ghc.context.client : ghc.types.context.client
local M = require("ghc.context.client.mod")

require("ghc.context.client.theme")
require("ghc.context.client.ui")

M:load({ silent_on_notfound = true })
M:auto_reload({
  on_changed = function()
    vim.defer_fn(function()
      M.reload_theme({ force = false })
    end, 200)
  end,
})

return M
