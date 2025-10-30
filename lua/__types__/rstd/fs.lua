---@meta

---@module 'rstd.fs'
---@class rstd.fs
local M = {}

---@class rstd.fs.IFileItemWithStatus
---@field public type                   string
---@field public name                   string
---@field public perm                   string
---@field public size                   string
---@field public owner                  string
---@field public group                  string
---@field public date                   string

---@class rstd.fs.IReaddirResult
---@field public itself                 rstd.fs.IFileItemWithStatus
---@field public items                  rstd.fs.IFileItemWithStatus[]

---@class rstd.fs.IReaddirError
---@field public error                  string

---@class rstd.fs.ICollectFilesResult
---@field public files                  string[]

---@class rstd.fs.ICollectFilesError
---@field public error                  string

---@class rstd.fs.IMoveParams
---@field public old_path               string
---@field public new_path               string
---@field public force                  boolean

---@class rstd.fs.IMoveError
---@field public error                  string

---@param dirpath                       string
---@param recursive                     boolean
---@return rstd.fs.ICollectFilesResult|nil
---@return rstd.fs.ICollectFilesError|nil
function M.collect_files(dirpath, recursive) end

---@param filepath                      string
---@return string|nil
---@return string|nil
function M.get_filesize(filepath) end

---@param dirpath                       string
---@return rstd.fs.IReaddirResult|nil
---@return rstd.fs.IReaddirError|nil
function M.readdir(dirpath) end

---@param params                        rstd.fs.IMoveParams
---@return boolean|nil
---@return rstd.fs.IMoveError|nil
function M.move(params) end

return M
