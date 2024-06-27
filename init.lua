vim.g.mapleader = " "

_G.fml = require("fml")
_G.ghc = require("ghc")

vim.o.statusline = "%!v:lua._G.ghc.ui.statusline.render()"

---load theme
vim.schedule(function()
  ghc.context.shared.reload_theme({ force = false })
end)

---@param name "keymap"|"option"|"autocmd"|"keymap-bootstrap"|"option-bootstrap"|"autocmd-bootstrap"
local function load_config(name)
  pcall(require, "guanghechen." .. name)

  if vim.g.neovide then
    pcall(require, "neovide." .. name)
  end

  pcall(require, "local." .. name)
end

-- bootstrap lazy and all plugins
local function load_plugins()
  local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
  if not vim.uv.fs_stat(lazypath) then
    local repo = "https://github.com/folke/lazy.nvim.git"
    vim.fn.system({ "git", "clone", "--filter=blob:none", repo, "--branch=stable", lazypath })
  end
  vim.opt.rtp:prepend(lazypath)

  -- load plugins
  require("lazy").setup(require("guanghechen.plugin.lazy"))
end

load_config("option-bootstrap")
load_config("keymap-bootstrap")
load_config("autocmd-bootstrap")

local ok = pcall(load_plugins)
if ok then
  load_config("option")
  load_config("keymap")
  load_config("autocmd")
else
  load_config("option")
end
