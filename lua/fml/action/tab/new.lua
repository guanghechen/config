---@class fml.action.tab
local M = {}

---@return integer
function M.new()
  vim.cmd("$tabnew")
  vim.bo.buflisted = false
  vim.bo.bufhidden = "wipe"

  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  era.tab.set_type(tabnr, era.tab.Types.NORMAL)
  era.tab.resolve(tabnr, false)
  return tabnr
end

---@return integer
function M.new_with_buf()
  local bufnr = vim.api.nvim_get_current_buf() ---@type integer

  vim.cmd("$tabnew")
  vim.bo.buflisted = false
  vim.bo.bufhidden = "wipe"

  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  era.tab.set_type(tabnr, era.tab.Types.NORMAL)

  local winnr = vim.api.nvim_tabpage_get_win(tabnr) ---@type integer
  vim.api.nvim_win_set_buf(winnr, bufnr)
  if vim.bo[bufnr].buflisted then
    era.tab.add_buf(tabnr, bufnr, false)
  end

  era.tab.resolve(tabnr, false)
  return tabnr
end

return M
