_G.eve = require("eve")

eve.setup_workspace()
require("eve.option")

eve.setup_state()

require("guanghechen.option")
require("guanghechen.plugin")

require("lazy").sync()
require("guanghechen.action.mason").install_all(false, function()
  vim.cmd("qa")
end)
