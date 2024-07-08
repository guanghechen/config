local state = require("fml.api.state")

vim.api.nvim_create_autocmd({ "TabNew" }, {
  callback = function(args)
    vim.notify("tab new: " .. vim.inspect(args))
  end,
})

vim.api.nvim_create_autocmd({ "TabClosed" }, {
  callback = function(args)
    vim.notify("tab close: " .. vim.inspect(args))
  end,
})