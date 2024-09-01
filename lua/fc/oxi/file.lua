---@class fc.oxi
local M = require("fc.oxi.mod")

---@class fc.oxi.IFileItemWithStatus
---@field public type                   string
---@field public name                   string
---@field public perm                   string
---@field public size                   string
---@field public owner                  string
---@field public group                  string
---@field public date                   string

---@class fc.oxi.IReaddirResult
---@field public itself                 fc.oxi.IFileItemWithStatus
---@field public items                  fc.oxi.IFileItemWithStatus[]

---@param dirpath                       string
---@return fc.oxi.IReaddirResult|nil
function M.readdir(dirpath)
  local ok, data = M.run_fun("fc.oxi.readdir", M.nvim_tools.readdir, dirpath)
  if ok then
    return data
  end
end
