local augroup = require("ghc.core.util.autocmd").augroup

-- Disable autoformat for lua files
vim.api.nvim_create_autocmd({ "FileType" }, {
  pattern = { "text", "toml", "json", "markdown" },
  callback = function()
    vim.b.autoformat = false
  end,
})

-- enable wrap in text filetypes
vim.api.nvim_create_autocmd("FileType", {
  group = augroup("wrap_spell"),
  pattern = { "markdown", "text" },
  callback = function()
    vim.opt_local.wrap = true
  end,
})
