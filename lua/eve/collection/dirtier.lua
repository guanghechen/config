local functional = require("eve.builtin.functional")
local Observable = require("eve.collection.observable")

---@class eve.collection.IDirtier : eve.collection.IObservable
---@field public is_clean               fun(self: eve.collection.IDirtier): boolean
---@field public is_dirty               fun(self: eve.collection.IDirtier): boolean
---@field public mark_clean             fun(self: eve.collection.IDirtier): nil
---@field public mark_dirty             fun(self: eve.collection.IDirtier): nil

---@class eve.collection.dirtier.IProps
---@field public dirty                  boolean
---@field public equals                 ?fun(a: unknown, b: unknown): boolean

---@class eve.collection.Dirtier : eve.collection.IDirtier
---@diagnostic disable-next-line: assign-type-mismatch
local M = {}
M.__index = M
setmetatable(M, Observable)

---@param props eve.collection.dirtier.IProps
---@return eve.collection.Dirtier
function M.new(props)
  local dirty = props.dirty ---@type boolean
  local equals = props.equals or functional.falsy

  local self = setmetatable(Observable.new({ initial_value = dirty, equals = equals }), M)
  ---@cast self                         eve.collection.Dirtier

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
