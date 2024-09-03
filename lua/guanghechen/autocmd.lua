--#plugin
vim.cmd([[autocmd User TelescopePreviewerLoaded setlocal number]]) -- enable numbers in telescope preview.

vim.api.nvim_create_autocmd("FileType", {
  pattern = {
    eve.constants.FT_NEOTREE,
    eve.constants.FT_SEARCH_INPUT,
    eve.constants.FT_SEARCH_MAIN,
    eve.constants.FT_SEARCH_PREVIEW,
    eve.constants.FT_TERM,
  },
  callback = function()
    pcall(function()
      require("cmp").setup.buffer({ enabled = false })
    end)
  end,
})
