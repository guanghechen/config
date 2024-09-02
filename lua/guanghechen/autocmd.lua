--#plugin
vim.cmd([[autocmd User TelescopePreviewerLoaded setlocal number]]) -- enable numbers in telescope preview.

vim.api.nvim_create_autocmd("FileType", {
  pattern = {
    eve.constants.FT_SELECT_INPUT,
    eve.constants.FT_SELECT_MAIN,
  },
  callback = function()
    pcall(function()
      require("cmp").setup.buffer({ enabled = false })
    end)
  end,
})
