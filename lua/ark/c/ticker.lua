---@class ark.c.ticker.IProps
---@field public start                  ?integer

---@class ark.c.Ticker : ark.c.Observable
---@diagnostic disable-next-line: assign-type-mismatch
local M = {}
M.__index = M
setmetatable(M, ark.c.Observable)

---@param props                         ?ark.c.ticker.IProps
---@return ark.c.Ticker
function M.new(props)
  local start = props and props.start or 0 ---@type integer
  local self = setmetatable(ark.c.Observable.from_value(start), M)
  ---@cast self                         ark.c.Ticker
  return self
end

---@return nil
function M:tick()
  local val = self:snapshot()
  self:next(val + 1)
end

return M
