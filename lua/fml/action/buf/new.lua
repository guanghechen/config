local path = require("eve.builtin.path")

local state = require("eve.state")

---@class fml.action.buf
local M = {}

---@param context                       eve.command.IContext
---@return nil
function M.new(context)
  local winnr = context.winnr ---@type integer
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

  vim.api.nvim_win_set_buf(winnr, bufnr)
end

return M
