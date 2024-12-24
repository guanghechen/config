local constant = require("eve.lib.constant")
local path = require("eve.lib.path")

---@class guanghechen.action.diffview
local M = {}

---@return nil
function M.diffview()
  local diffview = require("diffview") ---@type any
  diffview.open()
end

---@return nil
function M.history()
  local diffview = require("diffview") ---@type any
  diffview.file_history()
end

---@return nil
function M.history_file()
  local diffview = require("diffview") ---@type any
  local filepath = path.current_filepath()
  diffview.file_history(nil, filepath)
end

---@return nil
function M.fs_cwd()
  local bufnr = vim.api.nvim_get_current_buf() ---@type integer
  local filetype = vim.bo[bufnr].filetype ---@type string
  if filetype == constant.FT_DIFFVIEW_FILES or filetype == constant.FT_DIFFVIEW_FILE_HISTORY then
    vim.cmd("DiffviewToggleFiles")
  else
    vim.cmd("DiffviewFocusFiles")
  end
end

return M
