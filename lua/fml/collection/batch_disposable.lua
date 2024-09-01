local BatchHandler = require("fml.collection.batch_handler")
local reporter = require("fc.std.reporter")

---@class fml.collection.BatchDisposable : fml.types.collection.IBatchDisposable
local M = {}
M.__index = M

---@return fml.collection.BatchDisposable
function M.new()
  local self = setmetatable({}, M)

  ---@type boolean
  self._disposed = false

  ---@type fml.types.collection.IDisposable[]
  self._disposables = {}
  return self
end

---@param disposables                   fml.types.collection.IDisposable[]
---@return nil
function M.dispose_all(disposables)
  if #disposables <= 0 then
    return
  end

  local handler = BatchHandler.new()
  for _, disposable in ipairs(disposables) do
    handler:run(function()
      disposable:dispose()
    end)
  end
  handler:summary("[fml.collection.batch_disposable.dispose_all] Encountered error(s) while disposing.")
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
    reporter.error({
      from = "fml.collection.BatchDisposable",
      subject = "dispose",
      message = "Failed to dispose all registered disposables.",
      details = { result = result },
    })
    return
  end
end

---@param disposable fml.types.collection.IDisposable
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
