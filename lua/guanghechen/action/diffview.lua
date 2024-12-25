local constant = require("eve.lib.constant")

---@class guanghechen.action.diffview
local M = {}

---@param context                       eve.lib.command.IContext
---@return nil
---@diagnostic disable-next-line: unused-local
function M.diffview(context)
  local diffview = require("diffview") ---@type any
  diffview.open()
end

---@param context                       eve.lib.command.IContext
---@return nil
---@diagnostic disable-next-line: unused-local
function M.history(context)
  local diffview = require("diffview") ---@type any
  diffview.file_history()
end

---@param context                       eve.lib.command.IContext
---@return nil
function M.history_file(context)
  local bufnr = context.bufnr ---@type integer
  local filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string

  local diffview = require("diffview") ---@type any
  diffview.file_history(nil, filepath)
end

---@param context                       eve.lib.command.IContext
---@return nil
function M.fs_cwd(context)
  local bufnr = context.bufnr ---@type integer
  local filetype = vim.bo[bufnr].filetype ---@type string
  if filetype == constant.FT_DIFFVIEW_FILES or filetype == constant.FT_DIFFVIEW_FILE_HISTORY then
    vim.cmd("DiffviewToggleFiles")
  else
    vim.cmd("DiffviewFocusFiles")
  end
end

return M
