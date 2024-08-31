local BatchDisposable = require("fml.collection.batch_disposable")
local Observable = require("fml.collection.observable")

---@class fml.global
local M = {}

M.observable_zen_mode = Observable.from_value(false)
M.disposable = BatchDisposable.new() ---@type fml.types.collection.IBatchDisposable
M.disposable:add_disposable(M.observable_zen_mode)

return M
