---@class stl.c.ticker.IProps
---@field public start                  ?integer

---@class stl.c.Ticker : stl.c.Observable
---@diagnostic disable-next-line: assign-type-mismatch
local M = {}
M.__index = M
setmetatable(M, stl.c.Observable)

---@param props                         ?stl.c.ticker.IProps
---@return stl.c.Ticker
function M.new(props)
  local start = props and props.start or 0 ---@type integer
  local self = setmetatable(stl.c.Observable.from_value(start), M)
  ---@cast self                         stl.c.Ticker
  return self
end

---@return nil
function M:tick()
  local val = self:snapshot()
  self:next(val + 1)
end

return M
