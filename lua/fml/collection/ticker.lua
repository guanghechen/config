local Observable = require("fml.collection.observable")

---@class fml.collection.Ticker : fml.types.collection.ITicker
local M = {}
M.__index = M

setmetatable(M, { __index = Observable })

---@class fml.collection.ticker.IProps
---@field public start                  ?integer

---@param props                         ?fml.collection.ticker.IProps
---@return fml.collection.Ticker
function M.new(props)
  local start = props and props.start or 0 ---@type integer
  local self = setmetatable(Observable.from_value(start), M)
  ---@cast self fml.collection.Ticker
  return self
end

---@return nil
function M:tick()
  local val = self:get_snapshot()
  self:next(val + 1)
end

return M
