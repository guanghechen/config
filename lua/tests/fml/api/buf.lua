-- fml.debug.log("fml.api.state:", {
--   bufs = fml.api.state.bufs,
--   tabs = fml.api.state.tabs,
-- })

local bufnrs = vim.api.nvim_list_bufs() ---@type integer[]
fml.debug.log("bufnrs:", bufnrs)
