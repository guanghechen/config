---@class fml.std.oxi
local M = require("fml.std.oxi.mod")

---@param dirpath                       string
---@return string[]
function M.readdir(dirpath)
  local ok, filenames = M.run_fun("fml.std.oxi.readdir", M.nvim_tools.readdir, dirpath)
  return ok and filenames or {}
end
