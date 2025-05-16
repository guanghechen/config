---@class std.collection.ITicker: std.collection.IObservable
---@field public tick                   fun(self: std.collection.ITicker): nil

---@class std.collection.ticker.IProps
---@field public start                  ?integer

---@class std.collection.Ticker : std.collection.ITicker
---@diagnostic disable-next-line: assign-type-mismatch
local M = {}
M.__index = M
setmetatable(M, std.Observable)

---@param props                         ?std.collection.ticker.IProps
---@return std.collection.Ticker
function M.new(props)
  local start = props and props.start or 0 ---@type integer
  local self = setmetatable(std.Observable.from_value(start), M)
  ---@cast self                         std.collection.Ticker
  return self
end

---@return nil
function M:tick()
  local val = self:snapshot()
  self:next(val + 1)
end

return M
