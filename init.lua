local load = {
  bootstrap = function()
    vim.g.mapleader = " "
    vim.g.base46_cache = vim.fn.stdpath("data") .. "/nvchad/base46/"
    vim.opt.shortmess:append("I") --Don't show the intro message when starting nvim

    -- bootstrap lazy and all plugins
    local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
    if not vim.uv.fs_stat(lazypath) then
      local repo = "https://github.com/folke/lazy.nvim.git"
      vim.fn.system({ "git", "clone", "--filter=blob:none", repo, "--branch=stable", lazypath })
    end
    vim.opt.rtp:prepend(lazypath)

    -- load plugins
    require("lazy").setup(require("ghc.plugin.lazy"))
  end,
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
  theme = function()
    dofile(vim.g.base46_cache .. "defaults")
    dofile(vim.g.base46_cache .. "statusline")
  end,
}

load.bootstrap()
load.option()
load.theme()
load.autocmd()

vim.schedule(function()
  load.keymap()
end)
