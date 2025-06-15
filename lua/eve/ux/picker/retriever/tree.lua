local __module_name__ = "eve.ux.picker.retriever.tree" ---@type string

---@class eve.ux.picker.ITreeRetrieverProps
---@field public name                   string

---@class eve.ux.picker.TreeRetriever
---@field public fullname               string
---@field protected _disposed           boolean
---@field protected _bufnr              integer
---@field protected _linecount          integer
---@field protected _childline          integer[]|nil
---@field protected _lnum2uuid          string[]
---@field protected _uuid2lnum          table<string, integer>|nil
local M = {}
M.__index = M

---@param props eve.ux.picker.ITreeRetrieverProps
---@return eve.ux.picker.TreeRetriever
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
---@param lnum2uuid                     table<integer, string>
---@param uuid2lnum                     table<string, integer>
---@param childline                     integer[]|nil
function M:attach(bufnr, lnum2uuid, uuid2lnum, childline)
  self:__health__()
  self._bufnr = bufnr
  self._childline = childline
  self._linecount = #lnum2uuid
  self._lnum2uuid = lnum2uuid
  self._uuid2lnum = uuid2lnum
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
