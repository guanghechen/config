local __module_name__ = "std.collection.buf_retriever" ---@type string

---@class std.collection.ITreeviewRetrieverProps
---@field public name                   string

---@class std.collection.TreeviewRetriever : std.collection.IDisposable
---@field public name                   string
---@field protected _disposed           boolean
---@field protected _bufnr              integer
---@field protected _uuid2lnum          table<string, integer>|nil
---@field protected _lnum2uuid          string[]|nil
---@field protected _childline          integer[]|nil
local M = {}
M.__index = M

---@param props std.collection.ITreeviewRetrieverProps
---@return std.collection.TreeviewRetriever
function M.new(props)
  local name = props.name ---@type string

  local self = setmetatable({}, M)
  self.name = name
  self._disposed = false
  self._bufnr = nil
  self._lnum2uuid = nil
  self._uuid2lnum = nil
  self._childline = nil
  return self
end

---@return nil
function M:dispose()
  if self._disposed then
    return nil
  end
  self._disposed = true

  self._bufnr = nil
  self._lnum2uuid = nil
  self._uuid2lnum = nil
  self._childline = nil
end

---@return boolean
function M:isdisposed()
  return self._disposed
end

---@param lnum                          integer
---@return string|nil
function M:retrieve_uuid(lnum)
  return self._lnum2uuid ~= nil and self._lnum2uuid[lnum] or nil
end

---@param uuid                          string
---@return integer|nil
function M:retrieve_lnum(uuid)
  return self._uuid2lnum ~= nil and self._uuid2lnum[uuid] or nil
end

---@param lnum                          integer
---@return integer|nil
function M:retrieve_lastchild_lnum(lnum)
  return self._childline ~= nil and self._childline[lnum] or nil
end

---@param bufnr                         integer
---@param uuids                         string[]
---@param childline                     integer[]|nil
function M:attach(bufnr, uuids, childline)
  local uuid2lnum = {} ---@type table<string, integer>

  local N = #uuids ---@type integer
  for lnum = 1, N, 1 do
    local uuid = uuids[lnum] ---@type string
    uuid2lnum[uuid] = lnum
  end

  self._bufnr = bufnr
  self._uuid2lnum = uuid2lnum
  self._lnum2uuid = vim.list_slice(uuids)
  self._childline = childline and vim.list_slice(childline) or nil
end

---@protected
---@return nil
function M:health()
  if self._disposed then
    local message = string.format("[%s#%s]Treeview (%s) has been disposed.", __module_name__, self.name) ---@type string
    error(message)
  end
end

return M
