---@class guanghechen.disposable.BatchDisposable.util
local util = {
  debug = require("guanghechen.util.debug"),
  disposable = require("guanghechen.util.disposable"),
}

---@class guanghechen.disposable.BatchDisposable : guanghechen.types.IBatchDisposable
local BatchDisposable = {}
BatchDisposable.__index = BatchDisposable

---@return guanghechen.disposable.BatchDisposable
function BatchDisposable.new()
  local self = setmetatable({}, BatchDisposable)

  ---@type boolean
  self._disposed = false

  ---@type guanghechen.types.IDisposable[]
  self._disposables = {}
  return self
end

---@return boolean
function BatchDisposable:isDisposed()
  return self._disposed
end

---@return nil
function BatchDisposable:dispose()
  if self._disposed then
    return
  end

  self._disposed = true
  if #self._disposables <= 0 then
    return
  end

  local ok, result = pcall(function()
    util.disposable.disposeAll(self._disposables)
  end)
  self._disposables = {}
  if not ok then
    error(util.debug.inspect(result))
  end
end

---@param disposable guanghechen.types.IDisposable
---@return nil
function BatchDisposable:registerDisposable(disposable)
  if disposable:isDisposed() then
    return
  end

  if self._disposed then
    disposable:dispose()
    return
  end

  table.insert(self._disposables, disposable)
end

return BatchDisposable
