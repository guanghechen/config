-- VSCode-specific option overrides
-- Note: ark/option.lua is already loaded by ark/bootstrap.lua
-- This file only contains VSCode-specific overrides

-- Line Numbers & Cursor ---------------------------------------------------------------------------
-- VSCode handles these UI elements natively
vim.o.relativenumber = dot.context.option.relativenumber:snapshot()
vim.o.cursorline = false
vim.o.signcolumn = "no"

-- Indentation -------------------------------------------------------------------------------------
-- Read from dot.context for user preference
vim.o.expandtab = dot.context.option.expandtab:snapshot()

-- Timing ------------------------------------------------------------------------------------------
-- VSCode needs longer timeout for key sequences
vim.o.timeoutlen = 1000
