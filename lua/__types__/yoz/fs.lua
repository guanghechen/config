---@meta

---@module 'yoz.fs'
---@class yoz.fs
local M = {}

---@class yoz.fs.IFileItemWithStatus
---@field public type                   string
---@field public name                   string
---@field public perm                   string
---@field public size                   string
---@field public owner                  string
---@field public group                  string
---@field public date                   string

---@class yoz.fs.IReaddirResult
---@field public itself                 yoz.fs.IFileItemWithStatus
---@field public items                  yoz.fs.IFileItemWithStatus[]

---@class yoz.fs.IReaddirError
---@field public error                  string

---@class yoz.fs.ICollectFilesResult
---@field public files                  string[]

---@class yoz.fs.ICollectFilesError
---@field public error                  string

---@class yoz.fs.IMoveParams
---@field public old_path               string
---@field public new_path               string
---@field public force                  boolean

---@class yoz.fs.IMoveError
---@field public error                  string

---Checks whether target is at or below source after resolving filesystem aliases.
---Both arguments must be native absolute local paths. Source must exist; target may not
---exist, but it must not contain `..` components.
---@param source                       string
---@param target                       string
---@return boolean|nil
---@return string|nil
function M.is_descendant(source, target) end

---@param dirpath                       string
---@param recursive                     boolean
---@return yoz.fs.ICollectFilesResult|nil
---@return yoz.fs.ICollectFilesError|nil
function M.collect_files(dirpath, recursive) end

---@param filepath                      string
---@return string|nil
---@return string|nil
function M.get_filesize(filepath) end

---@param dirpath                       string
---@return yoz.fs.IReaddirResult|nil
---@return yoz.fs.IReaddirError|nil
function M.readdir(dirpath) end

---@param params                        yoz.fs.IMoveParams
---@return boolean|nil
---@return yoz.fs.IMoveError|nil
function M.move(params) end

return M
