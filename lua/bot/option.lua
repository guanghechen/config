local icons = require("ark.icon")

-- Global Variables --------------------------------------------------------------------------------

vim.g.bigfile_size = 1.5 * 1024 * 1024 --- 1.5MB
vim.g.bigfile_line_length = 2500
vim.g.markdown_recommended_style = 0 -- fix markdown indentation settings
vim.g.qf_disable_statusline = true

-- Disabled Providers ------------------------------------------------------------------------------

vim.g.loaded_node_provider = 0
vim.g.loaded_perl_provider = 0
vim.g.loaded_python3_provider = 0
vim.g.loaded_ruby_provider = 0

-- Encoding & File Format --------------------------------------------------------------------------

vim.o.encoding = "utf-8"
vim.o.fileencoding = "utf-8"
vim.o.fileencodings = "utf-8,gbk,latin1"
vim.o.fileformat = "unix"
vim.o.fileformats = "unix,dos"

-- Backup & Undo -----------------------------------------------------------------------------------

vim.o.backup = false
vim.o.backupcopy = "yes"
vim.o.swapfile = false
vim.o.undofile = true
vim.o.undolevels = 10000

-- UI Layout ---------------------------------------------------------------------------------------

vim.o.laststatus = 3 -- Keep only the global status bar
vim.o.ruler = false -- Disable the default ruler
vim.o.showtabline = 2
vim.o.showmode = false -- Dont show mode since we have a statusline
vim.o.splitbelow = true
vim.o.splitright = true
vim.o.splitkeep = "screen"

-- Line Numbers & Cursor ---------------------------------------------------------------------------

vim.o.number = true
vim.o.cursorline = true
vim.o.cursorlineopt = "number,screenline"
vim.o.cursorcolumn = false

-- Indentation -------------------------------------------------------------------------------------

vim.o.autoindent = true
vim.o.breakindent = true
vim.o.shiftround = true
vim.o.shiftwidth = 2
vim.o.smartindent = true
vim.o.smarttab = true
vim.o.softtabstop = 2
vim.o.tabstop = 2

-- Text Display ------------------------------------------------------------------------------------

vim.o.conceallevel = 0 -- Disable conceal
vim.o.linebreak = true -- Wrap lines at convenient points
vim.o.list = true -- Show invisible characters
vim.o.wrap = false
vim.o.syntax = "off"

-- Scrolling ---------------------------------------------------------------------------------------

vim.o.scrolloff = 4
vim.o.sidescrolloff = 8
vim.o.smoothscroll = true

-- Folding -----------------------------------------------------------------------------------------

vim.o.foldcolumn = "0"
vim.o.foldenable = true
vim.o.foldexpr = "0"
vim.o.foldlevel = 99
vim.o.foldlevelstart = 99
vim.o.foldmethod = "expr"

-- Search ------------------------------------------------------------------------------------------

vim.o.grepformat = "%f:%l:%c:%m"
vim.o.grepprg = "rg --vimgrep"
vim.o.hlsearch = true
vim.o.ignorecase = true
vim.o.incsearch = true
vim.o.smartcase = true

-- Completion & Command Line -----------------------------------------------------------------------

vim.o.completeopt = "menuone,noselect,popup"
vim.o.inccommand = "nosplit" -- Preview incremental substitute
vim.o.wildmode = "longest:full,full"

-- Popup & Window ----------------------------------------------------------------------------------

vim.o.pumblend = 10
vim.o.pumheight = 10
vim.o.winborder = "rounded"
vim.o.winminwidth = 10

-- Editing Behavior --------------------------------------------------------------------------------

vim.o.autowrite = true
vim.o.backspace = "indent,eol,start"
vim.o.confirm = true -- Confirm to save changes before exiting modified buffer
vim.o.formatoptions = "roq2lj"
vim.o.jumpoptions = "view"
vim.o.virtualedit = "block" -- Allow cursor to move where there is no text in visual block mode

-- Timing ------------------------------------------------------------------------------------------

vim.o.timeout = true
vim.o.timeoutlen = vim.g.vscode and 1000 or 300
vim.o.updatetime = 200

-- Spell -------------------------------------------------------------------------------------------

vim.o.spell = false
vim.o.spelllang = "en"

-- Diff --------------------------------------------------------------------------------------------

vim.o.diffopt = table.concat({
  "algorithm:histogram",
  "closeoff",
  "context:0",
  "filler",
  "indent-heuristic",
  "internal",
  "linematch:100",
  "vertical",
}, ",")

-- Appearance --------------------------------------------------------------------------------------

vim.o.guifont = "Maple Mono NF CN"
vim.o.termguicolors = true

-- Special Characters ------------------------------------------------------------------------------

vim.opt.mouse:append("a")
vim.opt.shortmess:append({ W = true, I = true, c = true, C = true })

vim.opt.fillchars:append(icons.fillchars)
vim.opt.listchars:append(icons.listchars)

-- Session & Persistence ---------------------------------------------------------------------------

vim.o.shada = "!,'100,<50,s10,h,rv" -- Exclude 'v' register from shada persistence
