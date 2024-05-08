vim.g.base46_cache = vim.fn.stdpath("data") .. "/nvchad/base46/"
vim.g.mapleader = " "

-- bootstrap lazy and all plugins
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  local repo = "https://github.com/folke/lazy.nvim.git"
  vim.fn.system({ "git", "clone", "--filter=blob:none", repo, "--branch=stable", lazypath })
end
vim.opt.rtp:prepend(lazypath)

require("ghc.option")

-- load plugins
require("lazy").setup(require("ghc.plugin.lazy"))

-- load theme
dofile(vim.g.base46_cache .. "defaults")
dofile(vim.g.base46_cache .. "statusline")

require("ghc.autocmd")

vim.schedule(function()
  require("ghc.keymap")
end)

if vim.g.neovide then
  require("neovide")
end
