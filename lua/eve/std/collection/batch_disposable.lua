local __module_name__ = "eve.std.collection.batch_disposable" ---@type string

---@class eve.std.collection.IBatchDisposable : eve.std.collection.IDisposable
---@field public dispose_all            fun(disposables: eve.std.collection.IDisposable[]): nil
---@field public add_disposable         fun(self: eve.std.collection.IBatchDisposable, disposable: eve.std.collection.IDisposable): nil

---@class eve.std.collection.BatchDisposable : eve.std.collection.IBatchDisposable
local M = {}
M.__index = M

---@return eve.std.collection.BatchDisposable
function M.new()
  local self = setmetatable({}, M)

  ---@type boolean
  self._disposed = false

  ---@type eve.std.collection.IDisposable[]
  self._disposables = {}
  return self
end

---@param disposables                   eve.std.collection.IDisposable[]
---@return nil
function M.dispose_all(disposables)
  if #disposables <= 0 then
    return
  end

  local handler = eve.std.BatchHandler.new()
  for _, disposable in ipairs(disposables) do
    handler:run(function()
      disposable:dispose()
    end)
  end
  handler:summary("[eve.std.collection.batch_disposable.dispose_all] Encountered error(s) while disposing.")
end

---@return boolean
function M:is_disposed()
  return self._disposed
end

---@return nil
function M:dispose()
  if self._disposed then
    return
  end

  self._disposed = true
  if #self._disposables <= 0 then
    return
  end

  local ok, result = pcall(function()
    M.dispose_all(self._disposables)
  end)
  self._disposables = {}

  if not ok then
    eve.reporter.error({
      from = __module_name__,
      subject = "dispose",
      message = "Failed to dispose all registered disposables.",
      details = { result = result },
    })
    return
  end
end

---@param disposable eve.std.collection.IDisposable
---@return nil
function M:add_disposable(disposable)
  if disposable:is_disposed() then
    return
  end

  if self._disposed then
    disposable:dispose()
    return
  end

  table.insert(self._disposables, disposable)
end

return M
