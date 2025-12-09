---@class eve.constant.diagnostic
local M = {}

local severity = vim.diagnostic.severity

---@type table<vim.diagnostic.Severity, string>
M.severity2prefixicon = {
  [severity.ERROR] = std.icon.diagnostic.Error_alt,
  [severity.WARN] = std.icon.diagnostic.Warning_alt,
  [severity.INFO] = std.icon.diagnostic.Information_alt,
  [severity.HINT] = std.icon.diagnostic.Hint_alt,
}

---@type table<vim.diagnostic.Severity, string>
M.severity2texticon = {
  [severity.ERROR] = std.icon.diagnostic.Error_alt,
  [severity.WARN] = std.icon.diagnostic.Warning_alt,
  [severity.INFO] = std.icon.diagnostic.Information_alt,
  [severity.HINT] = std.icon.diagnostic.Hint_alt,
}

---@type table<vim.diagnostic.Severity, string>
M.severity2numhl = {
  [severity.ERROR] = "f_lnum_error",
  [severity.WARN] = "f_lnum_warn",
  [severity.INFO] = "f_lnum_info",
  [severity.HINT] = "f_lnum_hint",
}

return M
