local state = require("fml.api.state")

---@class fml.api.tab
local M = require("fml.api.tab.mod")

---@param bufnr                         ?integer
---@param name                          ?string|nil
---@return nil
function M.create(bufnr, name)
  vim.cmd("$tabnew")

  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer

  if bufnr ~= nil then
    local winnr = vim.api.nvim_get_current_win() ---@type integer
    vim.api.nvim_win_set_buf(winnr, bufnr)
  end

  state.refresh_tab(tabnr)
  if name and state.tabs[tabnr] then
    state.tabs[tabnr].name = name
  end
end

---@param name                          ?string
function M.create_with_buf(name)
  local winnr = vim.api.nvim_get_current_win()
  local bufnr = vim.api.nvim_win_get_buf(winnr)
  local cursor = vim.api.nvim_win_get_cursor(winnr)

  M.create(bufnr, name)

  vim.api.nvim_win_set_cursor(winnr, cursor)
end
