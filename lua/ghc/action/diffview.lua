local ft = require("eve.constant.filetype")

---@class ghc.action.diffview
local M = {}

---@param context                       eve.command.IContext
---@return nil
---@diagnostic disable-next-line: unused-local
function M.diffview(context)
  local diffview = require("diffview") ---@type any
  diffview.open()
end

---@param context                       eve.command.IContext
---@return nil
---@diagnostic disable-next-line: unused-local
function M.history(context)
  local diffview = require("diffview") ---@type any
  diffview.file_history()
end

---@param context                       eve.command.IContext
---@return nil
function M.history_file(context)
  local bufnr = context.bufnr ---@type integer
  local filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string

  local diffview = require("diffview") ---@type any
  diffview.file_history(nil, filepath)
end

---@param context                       eve.command.IContext
---@return nil
function M.fs_cwd(context)
  local bufnr = context.bufnr ---@type integer
  local filetype = vim.bo[bufnr].filetype ---@type string
  if filetype == ft.DIFFVIEW_FILES or filetype == ft.DIFFVIEW_FILE_HISTORY then
    vim.cmd("DiffviewToggleFiles")
  else
    vim.cmd("DiffviewFocusFiles")
  end
end

return M
