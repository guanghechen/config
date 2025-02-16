_G.eve = require("eve")
eve.setup_patches()
eve.setup_workspace()
require("eve.option")

local default_storage = eve.get_default_storage() ---@type eve.state.storage
local storage = { editor = default_storage.editor, workspace = default_storage.workspace } ---@type eve.state.storage
eve.setup_state(storage)

require("ghc.plugin")

-- vim.api.nvim_create_autocmd("User", {
--   pattern = "LazyDone",
--   callback = function()
--     require("ghc.action.mason").install_all(false, function()
--       vim.cmd("qa")
--     end)
--   end,
-- })
-- local ok = pcall(function()
--   require("lazy").update()
-- end)
-- if not ok then
--   vim.cmd("qa")
-- end
vim.cmd("qa")
