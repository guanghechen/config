vim.o.expandtab = dot.context.option.expandtab:snapshot()
vim.o.relativenumber = dot.context.option.relativenumber:snapshot()
vim.o.signcolumn = "yes"

vim.opt.fillchars:append(dot.icon.fillchars)
vim.opt.listchars:append(dot.icon.listchars)
