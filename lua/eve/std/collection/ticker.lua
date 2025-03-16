---@class eve.std.collection.ITicker: eve.std.collection.IObservable
---@field public tick                   fun(self: eve.std.collection.ITicker): nil

---@class eve.std.collection.ticker.IProps
---@field public start                  ?integer

---@class eve.std.collection.Ticker : eve.std.collection.ITicker
---@diagnostic disable-next-line: assign-type-mismatch
local M = {}
M.__index = M
setmetatable(M, eve.std.Observable)

---@param props                         ?eve.std.collection.ticker.IProps
---@return eve.std.collection.Ticker
function M.new(props)
  local start = props and props.start or 0 ---@type integer
  local self = setmetatable(eve.std.Observable.from_value(start), M)
  ---@cast self                         eve.std.collection.Ticker
  return self
end

---@return nil
function M:tick()
  local val = self:snapshot()
  self:next(val + 1)
end

return M
