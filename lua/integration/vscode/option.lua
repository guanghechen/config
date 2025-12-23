vim.o.expandtab = dot.context.option.expandtab:snapshot()
vim.o.relativenumber = dot.context.option.relativenumber:snapshot()
vim.o.signcolumn = "no"

vim.opt.fillchars:append(ark.icon.fillchars)
vim.opt.listchars:append(ark.icon.listchars)
