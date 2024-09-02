local global = require("fml.global")

vim.api.nvim_create_autocmd("VimLeavePre", {
  once = true,
  callback = function()
    global.disposable:dispose()
  end,
})
