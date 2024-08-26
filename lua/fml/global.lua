local BatchDisposable = require("fml.collection.batch_disposable")

---@class fml.global
local M = {}

M.disposable = BatchDisposable.new() ---@type fml.types.collection.IBatchDisposable

return M
