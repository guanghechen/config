vim.g.mapleader = " "
vim.opt.laststatus = 3 -- Keep only the global status bar.
vim.opt.showtabline = 2
vim.opt.statusline = "%!v:lua._G.ghc.ui.statusline.render()"
vim.opt.tabline = "%!v:lua._G.ghc.ui.tabline.render()"

vim.opt.shortmess:append("I") --Don't show the intro message when starting nvim

-- disable some default providers
vim.g.loaded_node_provider = 0
vim.g.loaded_perl_provider = 0
vim.g.loaded_python3_provider = 0
vim.g.loaded_ruby_provider = 0

-- encoding
vim.opt.fileencoding = "utf-8"
vim.opt.fileformat = "unix"
vim.opt_global.fileencodings = "utf-8"
