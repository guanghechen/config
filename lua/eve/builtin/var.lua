---@class eve.builtin.var
local M = {}

---@class eve.builtin.vars.Names
M.Names = {
  BUF_DISABLE_AUTO_FORMAT = "eve_buf_disable_auto_format",
  BUF_DISABLE_LINT = "eve_buf_disable_lint",
  BUFID_MIDDLE = "eve_bufid_middle",
  NEO_TREE_SOURCE = "neo_tree_source",
  WINLINE_DISABLED = "eve_winline_disabled",
}

---@class eve.builtin.vars.Namespaces
M.Namespaces = {
  hipairs = vim.api.nvim_create_namespace("eve.ux.hipairs"),
  printer_default = vim.api.nvim_create_namespace("eve.ux.printer.default"),

  search_input = vim.api.nvim_create_namespace("eve.ux.search.input"),
  search_main = vim.api.nvim_create_namespace("eve.ux.search.main"),
  search_preview = vim.api.nvim_create_namespace("eve.ux.search.preview"),

  select_popup = vim.api.nvim_create_namespace("eve.ux.select_popup"),
}

return M
