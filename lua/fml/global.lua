local BatchDisposable = require("fc.collection.batch_disposable")
local Observable = require("fc.collection.observable")

---@class fml.global
local M = {}

M.observable_zen_mode = Observable.from_value(false)
M.disposable = BatchDisposable.new() ---@type fc.types.collection.IBatchDisposable
M.disposable:add_disposable(M.observable_zen_mode)

return M
