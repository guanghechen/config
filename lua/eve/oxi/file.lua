---@class eve.oxi
local M = require("eve.oxi.mod")

---@class eve.oxi.IFileItemWithStatus
---@field public type                   string
---@field public name                   string
---@field public perm                   string
---@field public size                   string
---@field public owner                  string
---@field public group                  string
---@field public date                   string

---@class eve.oxi.IReaddirResult
---@field public itself                 eve.oxi.IFileItemWithStatus
---@field public items                  eve.oxi.IFileItemWithStatus[]

---@param dirpath                       string
---@return eve.oxi.IReaddirResult|nil
function M.readdir(dirpath)
  local ok, data = M.run_fun("eve.oxi.readdir", M.nvim_tools.readdir, dirpath)
  if ok then
    return data
  end
end

---@param filepath string
---@return string|nil
function M.get_filesize(filepath)
  local stat = vim.uv.fs_stat(filepath)
  if stat == nil or stat.type ~= "file" then
    return nil
  end

  local ok, data = M.run_fun("eve.oxi.get_filesize", M.nvim_tools.get_filesize, filepath)
  if ok then
    return data
  end
end
