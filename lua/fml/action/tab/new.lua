local state = require("eve.state")

---@class fml.action.tab
local M = {}

---@return integer
function M.new()
  vim.cmd("$tabnew")
  vim.bo.buflisted = false
  vim.bo.bufhidden = "wipe"

  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  state.tab.tab_history:push(tabnr)
  state.tab.resolve(tabnr)
  return tabnr
end

function M.new_with_buf(context)
  vim.cmd("$tabnew")
  vim.bo.buflisted = false
  vim.bo.bufhidden = "wipe"

  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local winnr = vim.api.nvim_tabpage_get_win(tabnr) ---@type integer
  local bufnr = context.bufnr ---@type integer
  local bufs = {} ---@type eve.t.state.tab.buf.state[]

  if bufnr ~= nil and eve.editor.is_buf_valid(bufnr) and eve.editor.is_buf_sourcefile(bufnr) then
    bufs[#bufs + 1] = { bufnr = bufnr, pinned = false } ---@type eve.t.state.tab.buf.state
  end

  eve.editor.set_tabtype(tabnr, eve.var.TabTypes.NORMAL)

  local meta = state.tab.Meta.new(tabnr, bufs, math.min(1, #bufs))
  state.tab.set(tabnr, meta)
  state.tab.tab_history:push(tabnr)

  if bufnr ~= nil and eve.editor.is_buf_valid(bufnr) then
    vim.api.nvim_win_set_buf(winnr, bufnr)
  end
  return tabnr
end

return M
