---@class fml.action.tab
local M = {}

---@return integer
function M.new()
  vim.cmd("$tabnew")
  vim.bo.buflisted = false
  vim.bo.bufhidden = "wipe"

  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  eve.tab.resolve(tabnr, false)
  return tabnr
end

---@return integer
function M.new_with_buf()
  local bufnr = vim.api.nvim_get_current_buf() ---@type integer

  vim.cmd("$tabnew")

  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  eve.tab.set_type(tabnr, eve.tab.Types.NORMAL)

  if vim.bo[bufnr].buflisted then
    eve.tab.add_buf(tabnr, bufnr, false)
  else
    vim.bo.bufhidden = "wipe"
  end

  return tabnr
end

return M
