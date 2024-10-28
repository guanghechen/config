---@class ghc.action.git
local M = {}

---@return nil
function M.open_diffview()
  local diffview = require("diffview") ---@type any
  diffview.open()
end

---@return nil
function M.open_diffview_filehistory()
  local diffview = require("diffview") ---@type any
  local filepath = eve.path.current_filepath()
  diffview.file_history(nil, filepath)
end

return M
