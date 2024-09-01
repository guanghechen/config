---@class fc.std.oxi
local M = require("fc.std.oxi.mod")

---@class fc.std.oxi.IFileItemWithStatus
---@field public type                   string
---@field public name                   string
---@field public perm                   string
---@field public size                   string
---@field public owner                  string
---@field public group                  string
---@field public date                   string

---@class fc.std.oxi.IReaddirResult
---@field public itself                 fc.std.oxi.IFileItemWithStatus
---@field public items                  fc.std.oxi.IFileItemWithStatus[]

---@param dirpath                       string
---@return fc.std.oxi.IReaddirResult|nil
function M.readdir(dirpath)
  local ok, data = M.run_fun("fc.std.oxi.readdir", M.nvim_tools.readdir, dirpath)
  if ok then
    return data
  end
end
