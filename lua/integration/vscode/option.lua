vim.o.expandtab = era.context.option.expandtab:snapshot()
vim.o.relativenumber = era.context.option.relativenumber:snapshot()
vim.o.signcolumn = "no"

vim.opt.fillchars:append(dot.icon.fillchars)
vim.opt.listchars:append(dot.icon.listchars)
