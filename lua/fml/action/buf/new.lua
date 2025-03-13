local path = require("eve.std.path")
local editor = require("eve.module.editor")
local state = require("eve.state")

---@class fml.action.buf
local M = {}

---@return nil
function M.new()
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local winnr_sourcefile = state.tab.get_winnr_sourcefile(tabnr) or editor.pick_sourcefile_win() ---@type integer|nil

  ---@type integer|nil
  if winnr_sourcefile == nil then
    return
  end

  local bufnr = vim.api.nvim_create_buf(true, true) ---@type integer
  vim.bo[bufnr].buflisted = true
  vim.bo[bufnr].buftype = ""
  vim.bo[bufnr].filetype = "text"
  vim.bo[bufnr].readonly = false
  vim.bo[bufnr].modifiable = true

  local cwd = path.cwd() ---@type string
  local filepath = state.buf.pick_filepath(cwd) ---@type string|nil
  if filepath ~= nil then
    vim.api.nvim_buf_set_name(bufnr, filepath)
    state.buf.refresh(bufnr)
  end

  vim.api.nvim_win_set_buf(winnr_sourcefile, bufnr)
end

return M
