---@class oxi.fs.IFileItemWithStatus
---@field public type                   string
---@field public name                   string
---@field public perm                   string
---@field public size                   string
---@field public owner                  string
---@field public group                  string
---@field public date                   string

---@class oxi.fs.IReaddirResult
---@field public itself                 oxi.fs.IFileItemWithStatus
---@field public items                  oxi.fs.IFileItemWithStatus[]

---@class oxi.fs
local M = {}

---@param dirpath                       string
---@return oxi.fs.IReaddirResult|nil
function M.readdir(dirpath)
  local nvim_tools = require("nvim_tools")
  local ok, data = oxi.fn.run_fun("readdir", nvim_tools.readdir, dirpath)
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

  local nvim_tools = require("nvim_tools")
  local ok, data = oxi.fn.run_fun("get_filesize", nvim_tools.get_filesize, filepath)
  if ok then
    return data
  end
end

---@class oxi.fs.ICollectFilesResult
---@field public files string[] # List of absolute file paths

---@param dirpath string
---@param recursive boolean
---@return oxi.fs.ICollectFilesResult|nil
function M.collect_files(dirpath, recursive)
  local nvim_tools = require("nvim_tools")
  local ok, data = oxi.fn.run_fun("collect_files", nvim_tools.collect_files, dirpath, recursive)
  if ok then
    return data
  end
end

---@class oxi.fs.IRenameParams
---@field public old_path string
---@field public new_path string
---@field public force boolean

---@class oxi.fs.IRenameResult
---@field public old_path string
---@field public new_path string
---@field public message string

---@param params oxi.fs.IRenameParams
---@return oxi.fs.IRenameResult|nil
function M.rename_path(params)
  local params_json = std.json.stringify(params)

  local nvim_tools = require("nvim_tools")
  local ok, data = oxi.fn.run_fun("rename_path", nvim_tools.rename_path, params_json)
  if ok then
    return data
  end
end

return M
