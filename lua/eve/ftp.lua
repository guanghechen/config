---gitcommit
vim.api.nvim_create_autocmd("FileType", {
  pattern = "gitcommit",
  callback = function()
    vim.opt_local.wrap = false
    vim.opt_local.spell = true
  end,
})

---html
vim.api.nvim_create_autocmd("FileType", {
  pattern = "html",
  callback = function()
    vim.opt_local.wrap = false
    vim.opt_local.spell = true
  end,
})

---markdown
vim.api.nvim_create_autocmd("FileType", {
  pattern = "markdown",
  callback = function()
    vim.opt_local.wrap = true
    vim.opt_local.linebreak = true
    vim.opt_local.spell = true
    vim.opt_local.textwidth = 0
    vim.opt_local.wrapmargin = 0
    vim.opt_local.formatoptions:append("t")

    vim.opt_local.shiftwidth = 2
    vim.opt_local.softtabstop = 2 -- set the tab width
    vim.opt_local.tabstop = 2 -- set the tab width
  end,
})

---text
vim.api.nvim_create_autocmd("FileType", {
  pattern = "text",
  callback = function()
    vim.opt_local.wrap = true
    vim.opt_local.linebreak = true
    vim.opt_local.spell = true
    vim.opt_local.textwidth = 0
    vim.opt_local.wrapmargin = 0
    vim.opt_local.formatoptions:append("t")
  end,
})
