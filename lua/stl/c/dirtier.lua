---@class stl.c.dirtier.IProps
---@field public dirty                  boolean
---@field public equals                 ?fun(a: unknown, b: unknown): boolean

---@class stl.c.Dirtier : stl.c.Observable
---@diagnostic disable-next-line: assign-type-mismatch
local M = {}
M.__index = M
setmetatable(M, stl.c.Observable)

---@param props                         stl.c.dirtier.IProps
---@return stl.c.Dirtier
function M.new(props)
  local dirty = props.dirty ---@type boolean
  local equals = props.equals or stl.fn.falsy

  local self = setmetatable(stl.c.Observable.new({ initial_value = dirty, equals = equals }), M)
  ---@cast self                         stl.c.Dirtier

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
