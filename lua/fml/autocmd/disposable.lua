local BatchDisposable = require("fml.collection.batch_disposable")

local disposable = BatchDisposable.new() ---@type fml.types.collection.IBatchDisposable

vim.api.nvim_create_autocmd("VimLeavePre", {
  once = true,
  callback = function()
    disposable:dispose()
  end,
})

return disposable
