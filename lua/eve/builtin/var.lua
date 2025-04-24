---@class eve.builtin.var
local M = {}

---@class eve.builtin.var.WinTypes
M.WinTypes = {
  UX_BOARD = "ux_board",
  UX_CMDLINE = "ux_cmdline",
  UX_INPUT = "ux_input",
  UX_MAXIMIZE = "ux_maximize",
  UX_NOTIFY = "ux_notify",
  UX_POPUPMENU = "ux_popupmenu",
  UX_SEARCH_INPUT = "ux_search_input",
  UX_SEARCH_MAIN = "ux_search_main",
  UX_SEARCH_PREVIEW = "ux_search_preview",
  UX_SELECT_POPUP = "ux_select_popup",
  UX_TERMINAL = "ux_terminal",
  UX_TEXTAREA = "ux_textarea",
  UX_WINPICKER = "ux_winpicker",
  UX_WINSEP = "ux_winsep",
}

---@class eve.builtin.vars.Names
M.Names = {
  BUF_DISABLE_AUTO_FORMAT = "eve_buf_disable_auto_format",
  BUF_DISABLE_LINT = "eve_buf_disable_lint",
  BUFID_MIDDLE = "eve_bufid_middle",
  FLAG_SOURCEFILE = "eve_is_sourcefile",
  NEO_TREE_SOURCE = "neo_tree_source",
  TAB_TYPE = "eve_tab_type",
  WINTYPE = "eve_wintype",
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
