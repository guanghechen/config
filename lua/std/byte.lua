---@class std.byte
local M = {}

---@class std.byte.BYTES
M.BYTES = {
  -- stylua: ignore start
  DOT         = 0x2e, --[[ '.'  ]]
  SLASH       = 0x2f, --[[ '/'  ]]
  COLON       = 0x3a, --[[ ':'  ]]
  AT          = 0x40, --[[ '@'  ]]
  BACKSLASH   = 0x5c, --[[ '\\' ]]
  -- stylua: ignore end
}

return M
