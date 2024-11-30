local Observable = require("eve.lib.collection.observable")

---@class eve.lib.collection.ITicker: eve.lib.collection.IObservable
---@field public tick                   fun(self: eve.lib.collection.ITicker): nil

---@class eve.lib.collection.ticker.IProps
---@field public start                  ?integer

---@class eve.lib.collection.Ticker : eve.lib.collection.ITicker
---@diagnostic disable-next-line: assign-type-mismatch
local M = setmetatable({}, { __index = Observable })

---@param props                         ?eve.lib.collection.ticker.IProps
---@return eve.lib.collection.Ticker
function M.new(props)
  local start = props and props.start or 0 ---@type integer
  local self = setmetatable(Observable.from_value(start), { __index = M })
  ---@cast self eve.lib.collection.Ticker
  return self
end

---@return nil
function M:tick()
  local val = self:snapshot()
  self:next(val + 1)
end

return M
