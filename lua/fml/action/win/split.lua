local state = require("eve.state")

---@param winnr_source                  integer
---@return nil
local function fork(winnr_source)
  local meta_forked = state.win.fork(winnr_source) ---@type eve.t.state.win.meta.state|nil
  if meta_forked ~= nil then
    local winnr_target = vim.api.nvim_get_current_win() ---@type integer
    state.win.set(winnr_target, meta_forked)
  end
end

---@class fml.action.win
local M = {}

---@param context                       eve.command.IContext
---@return nil
function M.split_above(context)
  vim.api.nvim_tabpage_set_win(context.tabnr, context.winnr)
  vim.opt.splitbelow = false
  vim.cmd("split")
  vim.opt.splitbelow = true
  fork(context.winnr)
end

---@param context                       eve.command.IContext
---@return nil
function M.split_right(context)
  vim.api.nvim_tabpage_set_win(context.tabnr, context.winnr)
  vim.opt.splitright = true
  vim.cmd("vsplit")
  fork(context.winnr)
end

---@param context                       eve.command.IContext
---@return nil
function M.split_below(context)
  vim.api.nvim_tabpage_set_win(context.tabnr, context.winnr)
  vim.opt.splitbelow = true
  vim.cmd("split")
  fork(context.winnr)
end

---@param context                       eve.command.IContext
---@return nil
function M.split_left(context)
  vim.api.nvim_tabpage_set_win(context.tabnr, context.winnr)
  vim.opt.splitright = false
  vim.cmd("vsplit")
  vim.opt.splitright = true
  fork(context.winnr)
end

return M
