local __module_name__ = "std.collection.batch_disposable" ---@type string

---@class std.collection.IBatchDisposable : std.collection.IDisposable
---@field public dispose_all            fun(disposables: std.collection.IDisposable[]): nil
---@field public add_disposable         fun(self: std.collection.IBatchDisposable, disposable: std.collection.IDisposable): std.collection.IBatchDisposable

---@class std.collection.BatchDisposable : std.collection.IBatchDisposable
local M = {}
M.__index = M

---@return std.collection.BatchDisposable
function M.new()
  local self = setmetatable({}, M)

  ---@type boolean
  self._disposed = false

  ---@type std.collection.IDisposable[]
  self._disposables = {}
  return self
end

---@param disposables                   std.collection.IDisposable[]
---@return nil
function M.dispose_all(disposables)
  if #disposables <= 0 then
    return
  end

  local handler = std.BatchHandler.new()
  for _, disposable in ipairs(disposables) do
    handler:run(function()
      disposable:dispose()
    end)
  end
  handler:summary("[std.collection.batch_disposable.dispose_all] Encountered error(s) while disposing.")
end

---@return boolean
function M:isdisposed()
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
    std.reporter.error({
      from = __module_name__,
      subject = "dispose",
      message = "Failed to dispose all registered disposables.",
      details = { result = result },
    })
    return
  end
end

---@param disposable std.collection.IDisposable
---@return std.collection.IBatchDisposable
function M:add_disposable(disposable)
  if disposable:isdisposed() then
    return self
  end

  if self._disposed then
    disposable:dispose()
    return self
  end

  table.insert(self._disposables, disposable)
  return self
end

return M
