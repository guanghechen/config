local __module_name__ = "std.collection.buf_retriever" ---@type string

---@class std.collection.IBufRetrieverProps
---@field public name                   string

---@class std.collection.BufRetriever : std.collection.IDisposable
---@field public name                   string
---@field protected _disposed           boolean
---@field protected _bufnr              integer
---@field protected _lnum2uuid          table<integer, string>
---@field protected _uuid2lnum          table<string, integer>
local M = {}
M.__index = M

---@param props std.collection.IBufRetrieverProps
---@return std.collection.BufRetriever
function M.new(props)
  local name = props.name ---@type string

  local self = setmetatable({}, M)
  self.name = name
  self._disposed = false
  self._bufnr = nil
  self._lnum2uuid = {}
  self._uuid2lnum = {}
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

---@param bufnr                         integer
---@param uuids                         string[]
function M:attach(bufnr, uuids)
  local lnum2uuid = {} ---@type table<integer, string>
  local uuid2lnum = {} ---@type table<string, integer>

  local N = #uuids ---@type integer
  for index = 1, N, 1 do
    local uuid = uuids[index] ---@type string
    lnum2uuid[index] = uuid
    uuid2lnum[uuid] = index
  end

  self._bufnr = bufnr
  self._lnum2uuid = lnum2uuid
  self._uuid2lnum = uuid2lnum
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
