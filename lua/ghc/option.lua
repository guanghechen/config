local icons = require("eve.builtin.icons")
local state = require("eve.state")
local get_clipboard = require("ghc.fn.get_clipboard")

vim.g.clipboard = get_clipboard()
vim.opt.fillchars = icons.fillchars
vim.opt.listchars:append(icons.listchars)
vim.opt.relativenumber = state.state.theme.relativenumber:snapshot()

-- better format: https://github.com/stevearc/conform.nvim/issues/372#issuecomment-2066778074
vim.opt.foldexpr = "v:lua.require'ghc.fn.foldexpr'()"
vim.opt.statuscolumn = "%!v:lua.require'ghc.fn.statuscolumn'()"
vim.opt.statusline = "%!v:lua.require'ghc.nvimbar.statusline'.render()"
vim.opt.tabline = "%!v:lua.require'ghc.nvimbar.tabline'.render()"
