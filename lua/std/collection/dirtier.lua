---@class std.collection.IDirtier : std.collection.IObservable
---@field public is_clean               fun(self: std.collection.IDirtier): boolean
---@field public is_dirty               fun(self: std.collection.IDirtier): boolean
---@field public mark_clean             fun(self: std.collection.IDirtier): nil
---@field public mark_dirty             fun(self: std.collection.IDirtier): nil

---@class std.collection.dirtier.IProps
---@field public dirty                  boolean
---@field public equals                 ?fun(a: unknown, b: unknown): boolean

---@class std.collection.Dirtier : std.collection.IDirtier
---@diagnostic disable-next-line: assign-type-mismatch
local M = {}
M.__index = M
setmetatable(M, std.Observable)

---@param props std.collection.dirtier.IProps
---@return std.collection.Dirtier
function M.new(props)
  local dirty = props.dirty ---@type boolean
  local equals = props.equals or std.fn.falsy

  local self = setmetatable(std.Observable.new({ initial_value = dirty, equals = equals }), M)
  ---@cast self                         std.collection.Dirtier

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
