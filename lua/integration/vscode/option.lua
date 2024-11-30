local icons = require("eve.builtin.icons")
local state = require("eve.state")

vim.opt.fillchars = icons.fillchars
vim.opt.listchars:append(icons.listchars)
vim.opt.relativenumber = state.state.theme.relativenumber:snapshot()
