---@class guanghechen.core.action.file
local M = {}

function M.new_file()
  vim.cmd("enew")
end

return M
