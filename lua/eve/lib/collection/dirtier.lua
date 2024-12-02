local Observable = require("eve.lib.collection.observable")

---@class eve.lib.collection.IDirtier : eve.lib.collection.IObservable
---@field public is_dirty               fun(self: eve.lib.collection.IDirtier): boolean
---@field public mark_clean             fun(self: eve.lib.collection.IDirtier): nil
---@field public mark_dirty             fun(self: eve.lib.collection.IDirtier): nil

---@class eve.lib.collection.Dirtier : eve.lib.collection.IDirtier
---@field protected _clean_tick         integer
---@diagnostic disable-next-line: assign-type-mismatch
local M = {}
M.__index = M
setmetatable(M, Observable)

function M.new()
  local self = setmetatable(Observable.from_value(0), M)
  ---@cast self eve.lib.collection.Dirtier

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
