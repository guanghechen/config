---@class ark.c.BatchHandler
local M = {}
M.__index = M

---@return ark.c.BatchHandler
function M.new()
  local self = setmetatable({}, M)
  self._errors = {} ---@type any[]
  self._summary = nil ---@type string|nil
  return self
end

---@return nil
function M:cleanup()
  self._errors = {}
  self._summary = nil
end

---@param fn                            fun(...: any): nil
---@param ...                           any
---@return nil
function M:run(fn, ...)
  local ok, error = pcall(fn, ...)
  if not ok then
    table.insert(self._errors, error)
    self._summary = nil
  end
end

---@param title                         string
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
