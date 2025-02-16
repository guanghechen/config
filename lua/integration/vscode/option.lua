local state = require("eve.state")

vim.o.relativenumber = state.option.relativenumber:snapshot()
vim.o.signcolumn = "no"
