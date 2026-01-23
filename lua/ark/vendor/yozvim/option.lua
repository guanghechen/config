-- Yozvim-specific option overrides
-- Note: ark/option.lua is already loaded by ark/bootstrap.lua

-- Line Numbers & Cursor ---------------------------------------------------------------------------
vim.o.relativenumber = dot.context.option.relativenumber:snapshot()
vim.o.signcolumn = "no"
vim.o.cursorline = false

-- Indentation -------------------------------------------------------------------------------------
-- Read from dot.context for user preference
vim.o.expandtab = dot.context.option.expandtab:snapshot()

-- Timing ------------------------------------------------------------------------------------------
-- VSCode needs longer timeout for key sequences
vim.o.timeoutlen = 1000
