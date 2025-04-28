---@class fml.action.tab
local M = {}

---@return integer
function M.new()
  vim.cmd("$tabnew")
  vim.bo.buflisted = false
  vim.bo.bufhidden = "wipe"

  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  eve.state.tab.tab_history:push(tabnr)
  eve.state.tab.resolve(tabnr)
  return tabnr
end

function M.new_with_buf()
  local bufnr = vim.api.nvim_get_current_buf() ---@type integer

  vim.cmd("$tabnew")
  vim.bo.bufhidden = "wipe"

  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  eve.tab.set_type(tabnr, eve.tab.Types.NORMAL)

  local bufs = {} ---@type eve.state.tab.buf.state[]
  if vim.bo[bufnr].buflisted then
    bufs[#bufs + 1] = { bufnr = bufnr, pinned = false } ---@type eve.state.tab.buf.state
  end

  local meta = eve.state.tab.Meta.new(tabnr, bufs)
  eve.state.tab.set(tabnr, meta)
  eve.state.tab.tab_history:push(tabnr)

  local winnr = vim.api.nvim_tabpage_get_win(tabnr) ---@type integer
  vim.schedule(function()
    if bufnr ~= nil and eve.buf.is_valid(bufnr) then
      vim.api.nvim_win_set_buf(winnr, bufnr)
    end
  end)
  return tabnr
end

return M
