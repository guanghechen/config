---@class fc.collection.BatchHandler : fc.types.collection.IBatchHandler
local M = {}
M.__index = M

---@return fc.collection.BatchHandler
function M.new()
  local self = setmetatable({}, M)

  ---@type any[]
  self._errors = {}

  ---@type string|nil
  self._summary = nil

  return self
end

---@return nil
function M:cleanup()
  self._errors = {}
  self._summary = nil
end

---@param action fun():nil
---@return nil
function M:run(action)
  local ok, error = pcall(action)
  if not ok then
    table.insert(self._errors, error)
    self._summary = nil
  end
end

---@param title string
---@return nil
function M:summary(title)
  if self._summary == nil then
    if #self._errors > 0 then
      self._summary = vim.inspect({
        title = title,
        details = self._errors,
      })
    end
  end
  if self._summary ~= nil then
    error(self._summary)
  end
end

return M
