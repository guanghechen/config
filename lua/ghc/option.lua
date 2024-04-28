vim.g.toggle_theme_icon = "   "

-- disable some default providers
vim.g.loaded_node_provider = 0
vim.g.loaded_perl_provider = 0
vim.g.loaded_python3_provider = 0
vim.g.loaded_ruby_provider = 0

----------------------------------------------------------------------------------------------------

-- encoding
vim.opt.fileencoding = "utf-8"
vim.opt_global.fileencodings = "utf-8"

-- mouse
vim.opt.mouse:append("a")

-- clipboard
vim.opt.clipboard = "" -- Don't bind the default register to the system clipboard

-- panel split
vim.opt.splitbelow = true
vim.opt.splitright = true
vim.opt.splitkeep = "screen"

-- appearance
vim.opt.autoindent = true
vim.opt.conceallevel = 0 -- Disable conceal.
vim.opt.cursorline = true -- ggtrue to highlight the row of the cursor.
vim.opt.cursorlineopt = "number,screenline"
vim.opt.cursorcolumn = false -- true to highlight the column of the cursor.
vim.opt.expandtab = true -- use spaces instead of tabs
vim.opt.foldenable = false
vim.opt.foldlevel = 99
vim.opt.guifont = { "RobotoMono Nerd Font" }
vim.opt.list = true -- Show some invisible characters (tabs...
vim.opt.laststatus = 3 -- Keep only the global status bar.
vim.opt.lazyredraw = false -- Close since this could make the `folke/noice.nvim` experience issues.
vim.opt.number = true -- Print line number
vim.opt.pumblend = 10 -- Popup blend
vim.opt.pumheight = 10 -- Maximum number of entries in a popup
vim.opt.relativenumber = true
vim.opt.scrolloff = 4 -- Lines of context
vim.opt.shiftround = true -- Round indent
vim.opt.shiftwidth = 2
vim.opt.showmode = false -- Dont show mode since we have a statusline
vim.opt.sidescrolloff = 8 -- Columns of context
vim.opt.signcolumn = "yes"
vim.opt.smartindent = true -- Insert indents automatically
vim.opt.smarttab = true
vim.opt.tabstop = 2 -- set the tab width
vim.opt.termguicolors = true
vim.opt.winminwidth = 5 -- Minimum window width
vim.opt.wrap = false

-- search
vim.opt.grepformat = "%f:%l:%c:%m"
vim.opt.grepprg = "rg --vimgrep"
vim.opt.ignorecase = true
vim.opt.smartcase = true -- Don't ignore case with capitals

-- misc
vim.opt.confirm = true -- Confirm to save changes before exiting modified buffer
vim.opt.updatetime = 200 -- Save swap file and trigger CursorHold
vim.opt.undofile = true
vim.opt.undolevels = 10000
vim.opt.virtualedit = "block" -- Allow cursor to move where there is no text in visual block mode
vim.opt.wildmode = "longest:full,full" -- Command-line completion mode
