_G.eve = require("eve")

eve.setup_workspace()
require("eve.option")

eve.setup_state()

require("guanghechen.option")
require("guanghechen.plugin")

vim.cmd("Lazy update")
vim.cmd("MasonInstallAll")
