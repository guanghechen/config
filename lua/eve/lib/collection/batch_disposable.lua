local __module_name__ = "eve.lib.collection.batch_disposable" ---@type string

local reporter = require("eve.lib.reporter")
local BatchHandler = require("eve.lib.collection.batch_handler")

---@class eve.lib.collection.IBatchDisposable : eve.lib.collection.IDisposable
---@field public dispose_all            fun(disposables: eve.lib.collection.IDisposable[]): nil
---@field public add_disposable         fun(self: eve.lib.collection.IBatchDisposable, disposable: eve.lib.collection.IDisposable): nil

---@class eve.lib.collection.BatchDisposable : eve.lib.collection.IBatchDisposable
local M = {}

---@return eve.lib.collection.BatchDisposable
function M.new()
  local self = setmetatable({}, { __index = M })

  ---@type boolean
  self._disposed = false

  ---@type eve.lib.collection.IDisposable[]
  self._disposables = {}
  return self
end

---@param disposables                   eve.lib.collection.IDisposable[]
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
  handler:summary("[eve.lib.collection.batch_disposable.dispose_all] Encountered error(s) while disposing.")
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
      from = __module_name__,
      subject = "dispose",
      message = "Failed to dispose all registered disposables.",
      details = { result = result },
    })
    return
  end
end

---@param disposable eve.lib.collection.IDisposable
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
