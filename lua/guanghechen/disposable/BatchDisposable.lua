local disposeAll = require("guanghechen.disposable.util").disposeAll

---@class guanghechen.disposable.BatchDisposable : IDisposable
local BatchDisposable = {}

---@param o table|nil
---@return guanghechen.disposable.BatchDisposable
function BatchDisposable:new(o)
  o = o or {}
  setmetatable(o, self)

  ---@type boolean
  self._disposed = false

  ---@type IDisposable[]
  self._disposables = {}
  return o
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
    disposeAll(self._disposables)
  end)
  self._disposables = {}
  if not ok then
    error(vim.fn.json_encode(result))
  end
end

---@param disposable IDisposable
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
