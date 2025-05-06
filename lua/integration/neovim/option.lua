vim.g.clipboard = eve.clipboard.get_clipboard()
vim.o.relativenumber = eve.state.option.relativenumber:snapshot()
vim.o.signcolumn = "yes"

-- better format: https://github.com/stevearc/conform.nvim/issues/372#issuecomment-2066778074
vim.o.formatexpr = "v:lua.require'conform'.formatexpr()"
vim.o.statuscolumn = "%!v:lua.require'fml.dressing.statuscolumn'.statuscolumn()"
