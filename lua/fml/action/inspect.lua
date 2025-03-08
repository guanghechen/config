local __module_name__ = "fml.action.inspect" ---@type string

local path = require("eve.builtin.path")
local reporter = require("eve.builtin.reporter")
local state = require("eve.state")

---@class fml.action.inspect
local M = {}

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
  local cwd = path.cwd() ---@type string
  local workspace = path.workspace() ---@type string
  local full_state = state.dump() ---@type eve.state.data

  reporter.info({
    from = __module_name__,
    subject = "inspect_state",
    details = {
      path = {
        cwd = cwd,
        workspace = workspace,
      },
      state = {
        theme = full_state.theme,
        bookmarks = full_state.bookmark,
        flight = full_state.flight,
        lsp = full_state.lsp,
        options = full_state.option,
        plugins = full_state.plugin,
      },
    },
  })
end

---@param context                       eve.command.IContext
---@return nil
---@diagnostic disable-next-line: unused-local
function M.inspect_state_full(context)
  local cwd = path.cwd() ---@type string
  local workspace = path.workspace() ---@type string

  reporter.info({
    from = __module_name__,
    subject = "inspect_state_full",
    details = {
      path = {
        cwd = cwd,
        workspace = workspace,
      },
      state = state.dump(),
    },
  })
end

---@param context                       eve.command.IContext
---@return nil
---@diagnostic disable-next-line: unused-local
function M.inspect_tree(context)
  vim.treesitter.inspect_tree()
  vim.api.nvim_input("I")
end

---@param context                       eve.command.IContext
---@return nil
---@diagnostic disable-next-line: unused-local
function M.inspect_window(context)
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  local bufnr = vim.api.nvim_get_current_buf() ---@type integer

  local buftype = vim.bo[bufnr].buftype ---@type string
  local filetype = vim.bo[bufnr].filetype ---@type string
  local filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string

  local meta_tab = state.tab.resolve(tabnr) ---@type eve.state.tab.meta.state|nil
  local meta_win = state.win.resolve(winnr) ---@type eve.t.state.win.meta.state|nil
  local meta_buf = state.buf.resolve(bufnr) ---@type eve.t.state.buf.meta.state|nil

  reporter.info({
    from = __module_name__,
    subject = "inspect_window",
    details = {
      _ = {
        bufnr = bufnr,
        tabnr = tabnr,
        winnr = winnr,
      },
      basic = {
        buftype = buftype or vim.NIL,
        filetype = filetype or vim.NIL,
        filepath = filepath or vim.NIL,
      },
      z_meta = {
        buf = meta_buf,
        tab = meta_tab,
        win = meta_win,
      },
    },
  })
end

return M
