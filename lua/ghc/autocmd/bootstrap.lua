---! Auto toggle realtive linenumber.
vim.api.nvim_create_autocmd({ "InsertLeave" }, {
  pattern = "*",
  callback = function()
    if vim.o.nu and vim.api.nvim_get_mode().mode == "n" then
      if ghc.context.client.relativenumber:snapshot() then
        vim.opt.relativenumber = true
      end
    end
  end,
})
vim.api.nvim_create_autocmd({ "InsertEnter" }, {
  pattern = "*",
  callback = function()
    if vim.o.nu then
      vim.opt.relativenumber = false
      vim.cmd("redraw")
    end
  end,
})