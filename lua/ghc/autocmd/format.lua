local augroup = require("ghc.core.util.autocmd").augroup

-- https://github.com/stevearc/conform.nvim/blob/master/doc/recipes.md#command-to-toggle-format-on-save
-- Disable autoformat for lua files
vim.api.nvim_create_autocmd({ "FileType" }, {
  group = augroup("disable_format"),
  pattern = { "text", "tmux", "toml", "json", "markdown" },
  callback = function()
    vim.b.disable_autoformat = true
  end,
})

-- enable wrap in text filetypes
vim.api.nvim_create_autocmd("FileType", {
  group = augroup("spell"),
  pattern = { "markdown", "text" },
  callback = function()
    vim.opt_local.wrap = true
  end,
})
