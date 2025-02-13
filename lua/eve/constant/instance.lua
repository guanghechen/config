local Observable = require("eve.collection.observable")

---@class eve.constant.instance
local M = {}

M.observable_truthy = Observable.from_value(true)

return M
