local checks = require("eve.lib.checks")
local constant = require("eve.lib.constant")
local state = require("eve.state")

---@class fml.action.tab
local M = {}

---@param context                       eve.lib.command.IContext
---@return integer
---@diagnostic disable-next-line: unused-local
function M.new(context)
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
  state.tab.tab_history:push(tabnr)

  local tabtype = constant.TT_NORMAL ---@type string
  local bufs = {} ---@type eve.t.state.tab.buf.state[]

  local bufnr = context.bufnr ---@type integer
  local winnr = state.tab.resolve_winnr_listed(tabnr) or 0 ---@type integer
  if checks.is_buf_valid(bufnr) then
    bufs[#bufs + 1] = { bufnr = bufnr, pinned = false } ---@type eve.t.state.tab.buf.state
    vim.api.nvim_win_set_buf(winnr, bufnr)
  end

  local meta = state.tab.Meta.new(tabnr, tabtype, winnr, bufs)
  state.tab.set(tabnr, meta)
  return tabnr
end

return M
