local context_session = require("ghc.core.context.session")

---@class ghc.core.action.context
local M = {}

function M.edit_session()
  local filepath = context_session:get_filepath() ---@type string
  vim.cmd("tabnew " .. filepath)
end

return M
