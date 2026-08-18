---@diagnostic disable-next-line: unused-local
local __module_name__ = "stl.os.fs" ---@type string

local path = require("stl.os.path")

local REQUIRED_ADAPTER_METHODS = {
  "stat",
  "exists",
  "is_dir",
  "mkdir_p",
  "rename",
  "delete",
  "scandir",
} ---@type string[]

---@param filepath                      string
---@return string|nil
---@return string|nil
local function to_local_os_path(filepath)
  if type(filepath) ~= "string" or filepath == "" then
    return nil, "bad_path"
  end

  if path.is_uri_like(filepath) then
    return nil, "bad_scheme"
  end

  local os_path = yoz.canonical_path.to_os_path(filepath) ---@type string
  if os_path == "" then
    return nil, "bad_path"
  end

  return os_path, nil
end

---@param dirpath                       string
---@return string|nil
---@return string|nil
local function to_local_os_dirpath(dirpath)
  if type(dirpath) ~= "string" or dirpath == "" then
    return nil, "bad_path"
  end

  if path.is_uri_like(dirpath) then
    return nil, "bad_scheme"
  end

  local os_path = yoz.canonical_path.to_os_path(dirpath) ---@type string
  if os_path == "" then
    return nil, "bad_path"
  end

  return os_path, nil
end

---@class stl.os.fs.IScandirEntry
---@field public name                   string
---@field public ftype                  string

---@class stl.os.fs.IAdapter
---@field public name                   string
---@field public stat                   fun(filepath: string): uv.fs_stat.result|nil, any|nil
---@field public exists                 fun(filepath: string): boolean
---@field public is_dir                 fun(filepath: string): boolean
---@field public mkdir_p                fun(dirpath: string): boolean, any|nil
---@field public rename                 fun(source_filepath: string, target_filepath: string): boolean, any|nil
---@field public delete                 fun(filepath: string, recursive?: boolean): boolean, any|nil
---@field public scandir                fun(dirpath: string): stl.os.fs.IScandirEntry[]|nil, any|nil

---@type stl.os.fs.IAdapter
local local_adapter = {
  name = "local",

  stat = function(filepath)
    local os_path, err = to_local_os_path(filepath) ---@type string|nil, string|nil
    if os_path == nil then
      return nil, err
    end
    return vim.uv.fs_stat(os_path), nil
  end,

  exists = function(filepath)
    local os_path = to_local_os_path(filepath) ---@type string|nil
    if os_path == nil then
      return false
    end
    local stat = vim.uv.fs_stat(os_path) ---@type uv.fs_stat.result|nil
    return stat ~= nil
  end,

  is_dir = function(filepath)
    local os_path = to_local_os_path(filepath) ---@type string|nil
    if os_path == nil then
      return false
    end
    local stat = vim.uv.fs_stat(os_path) ---@type uv.fs_stat.result|nil
    return stat ~= nil and stat.type == "directory"
  end,

  mkdir_p = function(dirpath)
    local os_dirpath, path_err = to_local_os_dirpath(dirpath) ---@type string|nil, string|nil
    if os_dirpath == nil then
      return false, path_err
    end

    local ok, mkdir_err = pcall(vim.fn.mkdir, os_dirpath, "p")
    if not ok then
      return false, mkdir_err
    end

    if vim.fn.isdirectory(os_dirpath) == 1 then
      return true, nil
    end

    return false, "mkdir_failed"
  end,

  rename = function(source_filepath, target_filepath)
    local source_os, source_err = to_local_os_path(source_filepath) ---@type string|nil, string|nil
    if source_os == nil then
      return false, source_err
    end

    local target_os, target_err = to_local_os_path(target_filepath) ---@type string|nil, string|nil
    if target_os == nil then
      return false, target_err
    end

    local ok, code = pcall(vim.fn.rename, source_os, target_os)
    if not ok then
      return false, code
    end
    if code ~= 0 then
      return false, code
    end
    return true, nil
  end,

  delete = function(filepath, recursive)
    local os_path, err = to_local_os_path(filepath) ---@type string|nil, string|nil
    if os_path == nil then
      return false, err
    end

    local ok, code
    if recursive then
      ok, code = pcall(vim.fn.delete, os_path, "rf")
    else
      ok, code = pcall(vim.fn.delete, os_path)
    end

    if not ok then
      return false, code
    end
    if code ~= 0 then
      return false, code
    end
    return true, nil
  end,

  scandir = function(dirpath)
    local os_dirpath, err = to_local_os_dirpath(dirpath) ---@type string|nil, string|nil
    if os_dirpath == nil then
      return nil, err
    end

    local handle = vim.uv.fs_scandir(os_dirpath) ---@type userdata|nil
    if handle == nil then
      return nil, "scandir_failed"
    end

    local entries = {} ---@type stl.os.fs.IScandirEntry[]
    while true do
      local name, ftype = vim.uv.fs_scandir_next(handle) ---@type string|nil, string|nil
      if name == nil then
        break
      end
      entries[#entries + 1] = { name = name, ftype = ftype or "" }
    end

    return entries, nil
  end,
}

---@class stl.os.fs
local M = {}

local adapter = local_adapter ---@type stl.os.fs.IAdapter

---@param next_adapter                  stl.os.fs.IAdapter
---@return nil
local function validate_adapter(next_adapter)
  if type(next_adapter) ~= "table" then
    error(string.format("[%s] Adapter must be a table", __module_name__))
  end

  for _, key in ipairs(REQUIRED_ADAPTER_METHODS) do
    if type(next_adapter[key]) ~= "function" then
      error(string.format("[%s] Adapter is missing method: %s", __module_name__, key))
    end
  end
end

---@param next_adapter                  stl.os.fs.IAdapter
---@return nil
function M.set_adapter(next_adapter)
  validate_adapter(next_adapter)
  adapter = next_adapter
end

---@return stl.os.fs.IAdapter
function M.get_adapter()
  return adapter
end

---@return nil
function M.reset_adapter()
  adapter = local_adapter
end

---@param filepath                      string
---@return uv.fs_stat.result|nil
---@return any|nil
function M.stat(filepath)
  return adapter.stat(filepath)
end

---@param filepath                      string
---@return boolean
function M.exists(filepath)
  return adapter.exists(filepath)
end

---@param filepath                      string
---@return boolean
function M.is_dir(filepath)
  return adapter.is_dir(filepath)
end

---@param dirpath                       string
---@return boolean
---@return any|nil
function M.mkdir_p(dirpath)
  return adapter.mkdir_p(dirpath)
end

---@param source_filepath               string
---@param target_filepath               string
---@return boolean
---@return any|nil
function M.rename(source_filepath, target_filepath)
  return adapter.rename(source_filepath, target_filepath)
end

---@param filepath                      string
---@param recursive                     ?boolean
---@return boolean
---@return any|nil
function M.delete(filepath, recursive)
  return adapter.delete(filepath, recursive)
end

---@param dirpath                       string
---@return stl.os.fs.IScandirEntry[]|nil
---@return any|nil
function M.scandir(dirpath)
  return adapter.scandir(dirpath)
end

return M
