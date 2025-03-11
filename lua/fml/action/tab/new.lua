local setting = require("eve.constant.setting")
local editor = require("eve.module.editor")
local state = require("eve.state")

---@class fml.action.tab
local M = {}

---@param context                       eve.command.IContext
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
  local winnr = vim.api.nvim_tabpage_get_win(tabnr) ---@type integer
  local bufnr = context.bufnr ---@type integer

  local tabtype = setting.tabtypes.NORMAL ---@type string
  local bufs = {} ---@type eve.t.state.tab.buf.state[]

  if bufnr ~= nil and bufnr > 0 and vim.api.nvim_buf_is_valid(bufnr) and editor.is_buf_sourcefile(bufnr) then
    bufs[#bufs + 1] = { bufnr = bufnr, pinned = false } ---@type eve.t.state.tab.buf.state
  end

  local meta = state.tab.Meta.new(tabnr, tabtype, bufs)
  state.tab.set(tabnr, meta)
  state.tab.tab_history:push(tabnr)

  if bufnr ~= nil and bufnr > 0 then
    vim.api.nvim_win_set_buf(winnr, bufnr)
  end
  return tabnr
end

return M
