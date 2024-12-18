local state = require("eve.state")

vim.g.clipboard = fml.fn.get_clipboard()
vim.opt.relativenumber = state.theme.relativenumber:snapshot()

-- better format: https://github.com/stevearc/conform.nvim/issues/372#issuecomment-2066778074
vim.opt.formatexpr = "v:lua.require'conform'.formatexpr()"
vim.opt.foldexpr = "v:lua.require'fml.fn.foldexpr'()"
vim.opt.statuscolumn = "%!v:lua.require'fml.fn.statuscolumn'()"
