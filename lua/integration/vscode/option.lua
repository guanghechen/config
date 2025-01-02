local icons = require("eve.constant.icon")

local state = require("eve.state")

vim.opt.fillchars = icons.fillchars
vim.opt.listchars:append(icons.listchars)
vim.opt.relativenumber = state.option.relativenumber:snapshot()
