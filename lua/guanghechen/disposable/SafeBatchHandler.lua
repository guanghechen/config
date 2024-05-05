---@class guanghechen.disposable.SafeBatchHandler.util
local util = {
  debug = require("guanghechen.util.debug"),
}

---@class guanghechen.disposable.SafeBatchHandler
local SafeBatchHandler = {}

---@param o? table|nil
---@return guanghechen.disposable.SafeBatchHandler
function SafeBatchHandler:new(o)
  o = o or {}
  setmetatable(o, self)
  self._index = self

  ---@type any[]
  self._errors = {}

  ---@type string|nil
  self._summary = nil

  return o
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
    self._summary = util.debug({
      title = title,
      details = self._errors,
    })
  end
  if self._summary ~= nil then
    error(self._summary)
  end
end

return SafeBatchHandler
