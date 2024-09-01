local Observable = require("fc.collection.observable")

---@class fc.collection.Ticker : fc.types.collection.ITicker
local M = {}
M.__index = M

setmetatable(M, { __index = Observable })

---@class fc.collection.ticker.IProps
---@field public start                  ?integer

---@param props                         ?fc.collection.ticker.IProps
---@return fc.collection.Ticker
function M.new(props)
  local start = props and props.start or 0 ---@type integer
  local self = setmetatable(Observable.from_value(start), M)
  ---@cast self fc.collection.Ticker
  return self
end

---@return nil
function M:tick()
  local val = self:snapshot()
  self:next(val + 1)
end

return M
