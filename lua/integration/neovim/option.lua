local state = require("eve.state")

vim.g.clipboard = eve.clipboard.get_clipboard()
vim.o.relativenumber = state.option.relativenumber:snapshot()

-- better format: https://github.com/stevearc/conform.nvim/issues/372#issuecomment-2066778074
vim.o.formatexpr = "v:lua.require'conform'.formatexpr()"
vim.o.foldexpr = "v:lua.require'fml.dressing.foldexpr'.foldexpr()"
vim.o.statuscolumn = "%!v:lua.require'fml.dressing.statuscolumn'.statuscolumn()"
vim.o.signcolumn = "yes"
