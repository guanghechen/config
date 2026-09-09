---@diagnostic disable-next-line: unused-local
local __module_name__ = "ark.vendor.yui.option" ---@type string

-- Line Numbers & Cursor ---------------------------------------------------------------------------
vim.api.nvim_set_option_value("relativenumber", dot.context.option.relativenumber:snapshot(), {})
vim.api.nvim_set_option_value("signcolumn", "no", {})
vim.api.nvim_set_option_value("cursorline", false, {})

-- Indentation -------------------------------------------------------------------------------------
vim.api.nvim_set_option_value("expandtab", dot.context.option.expandtab:snapshot(), {})

-- Timing ------------------------------------------------------------------------------------------
vim.o.timeoutlen = 1000
