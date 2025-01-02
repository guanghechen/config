local clipboard = require("eve.lib.clipboard")
local state = require("eve.state")

vim.g.clipboard = clipboard.get_clipboard()
vim.opt.relativenumber = state.option.relativenumber:snapshot()

-- better format: https://github.com/stevearc/conform.nvim/issues/372#issuecomment-2066778074
vim.opt.formatexpr = "v:lua.require'conform'.formatexpr()"
vim.opt.foldexpr = "v:lua.require'eve.lib.fold'.foldexpr()"
vim.opt.statuscolumn = "%!v:lua.require'eve.module.statuscolumn'.statuscolumn()"
