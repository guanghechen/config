---@class fml.std.oxi
local M = require("fml.std.oxi.mod")

---@class fml.std.oxi.IFileItemWithStatus
---@field public type                   string
---@field public name                   string
---@field public perm                   string
---@field public size                   string
---@field public owner                  string
---@field public group                  string
---@field public date                   string

---@class fml.std.oxi.IReaddirResult
---@field public itself                 fml.std.oxi.IFileItemWithStatus
---@field public items                  fml.std.oxi.IFileItemWithStatus[]

---@param dirpath                       string
---@return fml.std.oxi.IReaddirResult|nil
function M.readdir(dirpath)
  local ok, data = M.run_fun("fml.std.oxi.readdir", M.nvim_tools.readdir, dirpath)
  if ok then
    return data
  end
end
