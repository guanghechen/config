local icons = require("eve.builtin.icons")
local state = require("eve.state")

vim.g.clipboard = fml.fn.get_clipboard()
vim.opt.fillchars = icons.fillchars
vim.opt.listchars:append(icons.listchars)
vim.opt.relativenumber = state.state.theme.relativenumber:snapshot()

-- better format: https://github.com/stevearc/conform.nvim/issues/372#issuecomment-2066778074
vim.o.formatexpr = "v:lua.require'conform'.formatexpr()"
vim.opt.foldexpr = "v:lua.require('eve.fn.foldexpr')()"
vim.opt.statusline = "%!v:lua._G.ghc.ux.statusline.render()"
vim.opt.tabline = "%!v:lua._G.ghc.ux.tabline.render()"
vim.opt.statuscolumn = "%!v:lua._G.fml.fn.statuscolumn()"
