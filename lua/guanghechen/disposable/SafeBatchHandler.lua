local util_debug = require("guanghechen.util.debug")

---@class guanghechen.disposable.SafeBatchHandler
local SafeBatchHandler = {}
SafeBatchHandler.__index = SafeBatchHandler

---@return guanghechen.disposable.SafeBatchHandler
function SafeBatchHandler.new()
  local self = setmetatable({}, SafeBatchHandler)

  ---@type any[]
  self._errors = {}

  ---@type string|nil
  self._summary = nil

  return self
end

---@return nil
function SafeBatchHandler:cleanup()
  self._errors = {}
  self._summary = nil
end

---@param action fun():nil
---@return nil
function SafeBatchHandler:run(action)
  local ok, error = pcall(action)
  if not ok then
    table.insert(self._errors, error)
    self._summary = nil
  end
end

---@param title string
---@return nil
function SafeBatchHandler:summary(title)
  if self._summary == nil then
    if #self._errors > 0 then
      self._summary = util_debug.inspect({
        title = title,
        details = self._errors,
      })
    end
  end
  if self._summary ~= nil then
    error(self._summary)
  end
end

return SafeBatchHandler
