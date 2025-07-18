local __module_name__ = "ghc.action.diffview" ---@type string

---@class ghc.action.diffview
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
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local bufnr_sourcefile = eve.tab.retrieve_bufnr_sourcefile(tabnr) ---@type integer|nil
  if bufnr_sourcefile == nil then
    return
  end

  local filepath = vim.api.nvim_buf_get_name(bufnr_sourcefile) ---@type string
  local diffview = require("diffview") ---@type any
  diffview.file_history(nil, filepath)
end

---@return nil
function M.fs_cwd()
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local bufnr_sourcefile = eve.tab.retrieve_bufnr_sourcefile(tabnr) ---@type integer|nil
  if bufnr_sourcefile == nil then
    return
  end

  local filetype = vim.bo[bufnr_sourcefile].filetype ---@type string
  if filetype == eve.filetype.DIFFVIEW_FILES or filetype == eve.filetype.DIFFVIEW_FILE_HISTORY then
    vim.cmd("DiffviewToggleFiles")
  else
    vim.cmd("DiffviewFocusFiles")
  end
end

---@return nil
function M.refresh()
  vim.cmd("DiffviewRefresh")
  std.reporter.info({
    from = __module_name__,
    message = "Refreshed!",
  })
end

---@return nil
function M.toggle()
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local tabtype = eve.tab.resolve_type(tabnr, false) ---@type eve.builtin.tab.TypeEnum

  if tabtype == eve.tab.Types.DIFFVIEW then
    vim.cmd("DiffviewToggleFiles")
  else
    vim.cmd("DiffviewFocusFiles")
  end
end

return M
