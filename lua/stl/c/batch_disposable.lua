local __module_name__ = "stl.c.batch_disposable" ---@type string

---@param disposables                   stl.c.IDisposable[]
---@return nil
local function dispose_all(disposables)
  if #disposables <= 0 then
    return
  end

  local handler = stl.c.BatchHandler.new()
  for _, disposable in ipairs(disposables) do
    handler:run(function()
      disposable:dispose()
    end)
  end
  handler:summary(string.format("[%s.dispose_all] Encountered error(s) while disposing.", __module_name__))
end

---@class stl.c.BatchDisposable : stl.c.IDisposable
local M = {}
M.__index = M

---@return stl.c.BatchDisposable
function M.new()
  local self = setmetatable({}, M)

  ---@type boolean
  self._disposed = false

  ---@type stl.c.IDisposable[]
  self._disposables = {}
  return self
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
    dispose_all(self._disposables)
  end)
  self._disposables = {}

  if not ok then
    stl.reporter.error({
      from = __module_name__,
      subject = "dispose",
      message = "Failed to dispose all registered disposables.",
      details = { result = result },
    })
    return
  end
end

---@param disposable                    stl.c.IDisposable
---@return stl.c.BatchDisposable
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
