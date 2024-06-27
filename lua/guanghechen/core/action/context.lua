---@class guanghechen.core.action.context
local M = {}

function M.edit_session()
  local filepath = ghc.context.session:get_filepath() ---@type string
  vim.cmd("noswapfile tabnew " .. filepath)
  vim.bo.backupcopy = "yes"
end

return M
