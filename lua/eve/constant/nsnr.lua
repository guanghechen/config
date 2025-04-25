---@class eve.constant.nsnr
local M = {}

M.attach = vim.api.nvim_create_namespace("ux_attach") ---@type integer
M.cmdline = vim.api.nvim_create_namespace("ux_cmdline") ---@type integer
M.notify = vim.api.nvim_create_namespace("ux_notify") ---@type integer
M.search_count = vim.api.nvim_create_namespace("ux_search_count") ---@type integer
M.popupmenu = vim.api.nvim_create_namespace("ux_popupmenu") ---@type integer
M.popupmenu_selected = vim.api.nvim_create_namespace("ux_popupmenu_selected") ---@type integer

return M
