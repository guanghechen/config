-- Disable autoformat for lua files
vim.api.nvim_create_autocmd({ "FileType" }, {
  pattern = { "toml", "json" },
  callback = function()
    vim.b.autoformat = false
  end,
})
