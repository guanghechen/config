local __module_name__ = "fml.action.debug" ---@type string

local reporter = require("eve.builtin.reporter")

local state = require("eve.state")

---@class fml.action.debug
local M = {}

---@param context                       eve.command.IContext
---@return nil
function M.inspect(context)
  local tabnr = context.tabnr ---@type integer
  local winnr = context.winnr ---@type integer
  local bufnr = context.bufnr ---@type integer
  local buftype = vim.bo[bufnr].buftype ---@type string

  local meta_tab = state.tab.resolve(tabnr) ---@type eve.state.tab.meta.state|nil
  local meta_win = state.win.resolve(winnr) ---@type eve.t.state.win.meta.state|nil
  local meta_buf = state.buf.resolve(bufnr) ---@type eve.t.state.buf.meta.state|nil

  reporter.info({
    from = __module_name__,
    subject = "inspect",
    details = {
      bufnr = bufnr,
      buftype = buftype or "nil",
      tabnr = tabnr,
      winnr = winnr,
      z_details = {
        meta_buf = meta_buf,
        meta_tab = meta_tab,
        meta_win = meta_win,
      },
    },
  })
end

---@param context                       eve.command.IContext
---@return nil
---@diagnostic disable-next-line: unused-local
function M.inspect_pos(context)
  vim.show_pos()
end

---@param context                       eve.command.IContext
---@return nil
---@diagnostic disable-next-line: unused-local
function M.inspect_state(context)
  local data = state.dump() ---@type eve.state.data
  reporter.info({
    from = __module_name__,
    subject = "inspect_state",
    details = { data = data },
  })
end

---@param context                       eve.command.IContext
---@return nil
---@diagnostic disable-next-line: unused-local
function M.inspect_tree(context)
  vim.cmd.InspectTree()
end

return M
