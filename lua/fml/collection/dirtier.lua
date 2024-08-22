local Observable = require("fml.collection.observable")

---@class fml.collection.Dirtier : fml.types.collection.IDirtier
---@field protected _clean_tick         integer
local M = {}
M.__index = M

setmetatable(M, { __index = Observable })

---@return fml.collection.Dirtier
function M.new()
  local self = setmetatable(Observable.from_value(0), M)
  ---@cast self fml.collection.Dirtier

  self._clean_tick = 0
  return self
end

---@return boolean
function M:is_dirty()
  local dirty_tick = self:snapshot() ---@type integer
  return self._clean_tick < dirty_tick
end

---@return nil
function M:mark_clean()
  local val = self:snapshot()
  self._clean_tick = val
end

---@return nil
function M:mark_dirty()
  local val = self:snapshot()
  self:next(val + 1)
end

return M
