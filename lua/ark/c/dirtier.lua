---@class ark.c.dirtier.IProps
---@field public dirty                  boolean
---@field public equals                 ?fun(a: unknown, b: unknown): boolean

---@class ark.c.Dirtier : ark.c.Observable
---@diagnostic disable-next-line: assign-type-mismatch
local M = {}
M.__index = M
setmetatable(M, ark.c.Observable)

---@param props                         ark.c.dirtier.IProps
---@return ark.c.Dirtier
function M.new(props)
  local dirty = props.dirty ---@type boolean
  local equals = props.equals or ark.fn.falsy

  local self = setmetatable(ark.c.Observable.new({ initial_value = dirty, equals = equals }), M)
  ---@cast self                         ark.c.Dirtier

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
