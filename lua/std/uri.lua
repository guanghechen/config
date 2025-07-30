---@class std.uri
local M = {}

---@param filepath                      string
---@param lnum_start                    integer
---@param col_start                     integer
---@param lnum_end                      integer
---@param col_end                       integer
function M.file_location(filepath, lnum_start, col_start, lnum_end, col_end)
  local uri = vim.uri_from_fname(filepath) ---@type string
  local location = string.format("%s#L%dC%d-L%dC%d", uri, lnum_start, col_start, lnum_end, col_end)
  return location
end

return M
