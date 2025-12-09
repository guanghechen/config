---@class eve.constant.diagnostic
local M = {}

local severity = vim.diagnostic.severity

---@type table<vim.diagnostic.Severity, string>
M.severity2prefixicon = {
  [severity.ERROR] = dot.icon.diagnostic.Error_alt,
  [severity.WARN] = dot.icon.diagnostic.Warning_alt,
  [severity.INFO] = dot.icon.diagnostic.Information_alt,
  [severity.HINT] = dot.icon.diagnostic.Hint_alt,
}

---@type table<vim.diagnostic.Severity, string>
M.severity2texticon = {
  [severity.ERROR] = dot.icon.diagnostic.Error_alt,
  [severity.WARN] = dot.icon.diagnostic.Warning_alt,
  [severity.INFO] = dot.icon.diagnostic.Information_alt,
  [severity.HINT] = dot.icon.diagnostic.Hint_alt,
}

---@type table<vim.diagnostic.Severity, string>
M.severity2numhl = {
  [severity.ERROR] = "f_lnum_error",
  [severity.WARN] = "f_lnum_warn",
  [severity.INFO] = "f_lnum_info",
  [severity.HINT] = "f_lnum_hint",
}

return M
