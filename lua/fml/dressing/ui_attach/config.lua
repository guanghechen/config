---@class fml.dressing.ui_attach.config
local M = {}

M.nsnr_attach = vim.api.nvim_create_namespace("ux_attach") ---@type integer
M.nsnr_search_count = vim.api.nvim_create_namespace("ux_search_count") ---@type integer

return M
