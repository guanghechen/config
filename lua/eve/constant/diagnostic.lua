---@class eve.constant.diagnostic
local M = {}

local severity = vim.diagnostic.severity

---@type table<vim.diagnostic.Severity, string>
M.severity2prefixicon = {
  [severity.ERROR] = eve.icon.diagnostic.Error_alt,
  [severity.WARN] = eve.icon.diagnostic.Warning_alt,
  [severity.INFO] = eve.icon.diagnostic.Information_alt,
  [severity.HINT] = eve.icon.diagnostic.Hint_alt,
}

---@type table<vim.diagnostic.Severity, string>
M.severity2texticon = {
  [severity.ERROR] = eve.icon.diagnostic.Error,
  [severity.WARN] = eve.icon.diagnostic.Warning,
  [severity.INFO] = eve.icon.diagnostic.Information,
  [severity.HINT] = eve.icon.diagnostic.Hint,
}

---@type table<vim.diagnostic.Severity, string>
M.severity2numhl = {
  [severity.ERROR] = "f_lnum_error",
  [severity.WARN] = "f_lnum_warn",
  [severity.INFO] = "f_lnum_info",
  [severity.HINT] = "f_lnum_hint",
}

return M
