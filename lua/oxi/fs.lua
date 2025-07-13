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
  local result = oxi.fn.safe_run("readdir", dirpath)
  return result
end

---@param filepath                      string
---@return string|nil
function M.get_filesize(filepath)
  local stat = vim.uv.fs_stat(filepath)
  if stat == nil or stat.type ~= "file" then
    return nil
  end

  local result = oxi.fn.safe_run("get_filesize", filepath)
  return result
end

---@class oxi.fs.ICollectFilesResult
---@field public files string[] # List of absolute file paths

---@param dirpath                       string
---@param recursive                     boolean
---@return oxi.fs.ICollectFilesResult|nil
function M.collect_files(dirpath, recursive)
  local result = oxi.fn.safe_run("collect_files", dirpath, recursive)
  return result
end

---@class oxi.fs.IMoveParams
---@field public old_path               string
---@field public new_path               string
---@field public force                  boolean

---@param params                        oxi.fs.IMoveParams
---@return boolean
function M.move(params)
  local result = oxi.fn.safe_run("move", params)
  return result == true
end

return M
