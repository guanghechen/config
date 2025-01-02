local Observable = require("eve.collection.observable")

---@class eve.collection.ITicker: eve.collection.IObservable
---@field public tick                   fun(self: eve.collection.ITicker): nil

---@class eve.collection.ticker.IProps
---@field public start                  ?integer

---@class eve.collection.Ticker : eve.collection.ITicker
---@diagnostic disable-next-line: assign-type-mismatch
local M = {}
M.__index = M
setmetatable(M, Observable)

---@param props                         ?eve.collection.ticker.IProps
---@return eve.collection.Ticker
function M.new(props)
  local start = props and props.start or 0 ---@type integer
  local self = setmetatable(Observable.from_value(start), M)
  ---@cast self                         eve.collection.Ticker
  return self
end

---@return nil
function M:tick()
  local val = self:snapshot()
  self:next(val + 1)
end

return M
