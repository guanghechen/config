require("neovide.autocmd")
require("neovide.keymap")
require("neovide.option")

--Try to load local config
pcall(require, "local.neovide")
