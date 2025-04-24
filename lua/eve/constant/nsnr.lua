---@class eve.constant.nsnr
local M = {}

M.attach = vim.api.nvim_create_namespace("ux_attach") ---@type integer
M.search_count = vim.api.nvim_create_namespace("ux_search_count") ---@type integer

return M
