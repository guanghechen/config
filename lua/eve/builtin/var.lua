---@class eve.builtin.var
local M = {}

---@class eve.builtin.var.TabTypes
M.TabTypes = {
  ALL = "all",
  DIFFVIEW = "diffview",
  NORMAL = "normal",
}

---@class eve.builtin.vars.Names
M.Names = {
  BUF_DISABLE_LINT = "eve_buf_disable_lint",
  BUFID_MIDDLE = "eve_bufid_middle",
  FLAG_SOURCEFILE = "eve_is_sourcefile",
  TAB_TYPE = "eve_tab_type",
  WINLINE_DISABLED = "eve_winline_disabled",
}

return M
