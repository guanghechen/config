---@class guanghechen.util.fs
local M = {}

function M.read_file(filepath)
  local lines = vim.fn.readfile(filepath)
  return table.concat(lines, "\n")
end

return M
