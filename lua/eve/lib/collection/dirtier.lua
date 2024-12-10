local functional = require("eve.lib.functional")
local Observable = require("eve.lib.collection.observable")

---@class eve.lib.collection.IDirtier : eve.lib.collection.IObservable
---@field public is_clean               fun(self: eve.lib.collection.IDirtier): boolean
---@field public is_dirty               fun(self: eve.lib.collection.IDirtier): boolean
---@field public mark_clean             fun(self: eve.lib.collection.IDirtier): nil
---@field public mark_dirty             fun(self: eve.lib.collection.IDirtier): nil

---@class eve.lib.collection.dirtier.IProps
---@field public dirty                  boolean
---@field public equals                 ?fun(a: unknown, b: unknown): boolean

---@class eve.lib.collection.Dirtier : eve.lib.collection.IDirtier
---@diagnostic disable-next-line: assign-type-mismatch
local M = {}
M.__index = M
setmetatable(M, Observable)

---@param props eve.lib.collection.dirtier.IProps
---@return eve.lib.collection.Dirtier
function M.new(props)
  local dirty = props.dirty ---@type boolean
  local equals = props.equals or functional.falsy

  local self = setmetatable(Observable.new({ initial_value = dirty, equals = equals }), M)
  ---@cast self eve.lib.collection.Dirtier

  return self
end

---@return boolean
function M:is_clean()
  return not self:snapshot() ---@type boolean
end

---@return boolean
function M:is_dirty()
  return self:snapshot() ---@type boolean
end

---@return nil
function M:mark_clean()
  self:next(false)
end

---@return nil
function M:mark_dirty()
  self:next(true)
end

return M
