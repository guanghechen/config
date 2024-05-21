local load = {
  autocmd = function()
    require("ghc.autocmd")

    if vim.g.neovide then
      require("neovide.autocmd")
    end

    pcall(require, "local.autocmd")
  end,
  keymap = function()
    require("ghc.keymap")

    if vim.g.neovide then
      require("neovide.keymap")
    end

    pcall(require, "local.keymap")
  end,
  option = function()
    require("ghc.option")

    if vim.g.neovide then
      require("neovide.option")
    end

    pcall(require, "local.option")
  end,
}

vim.g.base46_cache = vim.fn.stdpath("data") .. "/nvchad/base46/"
vim.g.mapleader = " "

-- bootstrap lazy and all plugins
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
  local repo = "https://github.com/folke/lazy.nvim.git"
  vim.fn.system({ "git", "clone", "--filter=blob:none", repo, "--branch=stable", lazypath })
end
vim.opt.rtp:prepend(lazypath)

load.option()

-- load plugins
require("lazy").setup(require("ghc.plugin.lazy"))

-- load theme
dofile(vim.g.base46_cache .. "defaults")
dofile(vim.g.base46_cache .. "statusline")

load.autocmd()

vim.schedule(function()
  load.keymap()
end)
