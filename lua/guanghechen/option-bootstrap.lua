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
