local state = require("fml.api.state")

---@class fml.api.win.IHistoryItem
---@field public bufnr number
---@field public filepath string

---@class fml.api.win.IHistoryItemEntry
---@field public display                string
---@field public ordinal                string
---@field public item                   fml.api.win.IHistoryItem
---@field public item_index             number

---@class fml.api.win
local M = {}

---@class fml.api.win.IDetails
---@field public winnr                  integer
---@field public bufnr                  integer
---@field public filepath               string|nil
---@field public dirpath                string|nil

---@param winnr                         integer
---@return fml.api.win.IDetails
function M.get_win_details(winnr)
  local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
  local filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string
  local filetype = eve.fs.is_file_or_dir(filepath) ---@type eve.enums.FileType|nil
  if filetype == "file" or filetype == "directory" then
    local dirpath = filetype == "file" and eve.path.dirname(filepath) or filepath ---@type string
    dirpath = eve.path.normalize(dirpath)
    return { winnr = winnr, bufnr = bufnr, filepath = filepath, dirpath = dirpath }
  end
  return { winnr = winnr, bufnr = bufnr }
end

---@return fml.api.win.IDetails|nil
function M.get_cur_win_details_if_valid()
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  return state.validate_win(winnr) and M.get_win_details(winnr) or nil
end

return M
