local __module_name__ = "eve.ux.view.tree_retriever" ---@type string

---@class eve.ux.view.ITreeRetrieverProps
---@field public name                   string

---@class eve.ux.view.TreeRetriever
---@field public fullname               string
---@field protected _disposed           boolean
---@field protected _bufnr              integer
---@field protected _linecount          integer
---@field protected _childline          integer[]|nil
---@field protected _lnum2uuid          string[]
---@field protected _uuid2lnum          table<string, integer>|nil
local M = {}
M.__index = M

---@param props eve.ux.view.ITreeRetrieverProps
---@return eve.ux.view.TreeRetriever
function M.new(props)
  local name = props.name ---@type string
  local fullname = string.format("%s -> %s", name, __module_name__) ---@type string

  local self = setmetatable({}, M)
  self.fullname = fullname
  self._disposed = false
  self._bufnr = nil
  self._linecount = 0
  self._childline = nil
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
  self._linecount = 0
  self._childline = nil
  self._lnum2uuid = nil
  self._uuid2lnum = nil
end

---@return boolean
function M:isdisposed()
  return self._disposed
end

---@return integer
function M:linecount()
  return self._linecount
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
  self:__health__()

  local lnum2uuid = self._lnum2uuid ---@type string[]
  local uuid2lnum = self._uuid2lnum ---@type table<string, integer>

  local N1 = #lnum2uuid ---@type integer
  for lnum = 1, N1, 1 do
    local uuid = lnum2uuid[lnum] ---@type string
    uuid2lnum[uuid] = nil
  end

  local N2 = #uuids ---@type integer
  for lnum = 1, N2, 1 do
    local uuid = uuids[lnum] ---@type string
    lnum2uuid[lnum] = uuid
    uuid2lnum[uuid] = lnum
  end

  if N1 > N2 then
    std.table.truncate_inline(lnum2uuid, N2)
  end

  if childline == nil then
    self._childline = nil
  else
    local cls = self._childline or {} ---@type integer[]
    for lnum = 1, N2, 1 do
      local cl = childline[lnum] ---@type integer
      cls[lnum] = cl
    end
    std.table.truncate_inline(cls, N2)
    self._childline = cls
  end

  self._bufnr = bufnr
  self._linecount = #lnum2uuid
end

---@protected
---@return nil
function M:__health__()
  if self._disposed then
    local message = string.format("[%s] has been disposed.", self.fullname) ---@type string
    error(message)
  end
end

return M
