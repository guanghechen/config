---@class eve.std.collection.IDirtier : eve.std.collection.IObservable -- boolean>
---@field public is_clean               fun(self: eve.std.collection.IDirtier): boolean
---@field public is_dirty               fun(self: eve.std.collection.IDirtier): boolean
---@field public mark_clean             fun(self: eve.std.collection.IDirtier): nil
---@field public mark_dirty             fun(self: eve.std.collection.IDirtier): nil

---@class eve.std.collection.dirtier.IProps
---@field public dirty                  boolean
---@field public equals                 ?fun(a: unknown, b: unknown): boolean

---@class eve.std.collection.Dirtier : eve.std.collection.IDirtier
---@diagnostic disable-next-line: assign-type-mismatch
local M = {}
M.__index = M
setmetatable(M, eve.std.Observable)

---@param props eve.std.collection.dirtier.IProps
---@return eve.std.collection.Dirtier
function M.new(props)
  local dirty = props.dirty ---@type boolean
  local equals = props.equals or eve.std.fn.falsy

  local self = setmetatable(eve.std.Observable.new({ initial_value = dirty, equals = equals }), M)
  ---@cast self                         eve.std.collection.Dirtier

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
