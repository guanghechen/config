local state = require("eve.state")

---@class fml.action.win
local M = {}

---@param context                       eve.command.IContext
---@return nil
function M.split_horizontal(context)
  local winnr = context.winnr ---@type integer

  vim.cmd("split")

  local meta_forked = state.win.fork(winnr) ---@type eve.t.state.win.meta.state|nil
  if meta_forked ~= nil then
    local winnr_new = vim.api.nvim_get_current_win() ---@type integer
    state.win.set(winnr_new, meta_forked)
  end
end

---@param context                       eve.command.IContext
---@return nil
function M.split_vertical(context)
  local winnr = context.winnr ---@type integer

  vim.cmd("vsplit")

  local meta_forked = state.win.fork(winnr) ---@type eve.t.state.win.meta.state|nil
  if meta_forked ~= nil then
    local winnr_new = vim.api.nvim_get_current_win() ---@type integer
    state.win.set(winnr_new, meta_forked)
  end
end

return M
