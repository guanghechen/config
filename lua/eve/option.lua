if std.env.IS_MAC or std.env.IS_NIX or std.env.IS_WSL then
  vim.o.shell = "/bin/bash"
elseif std.env.IS_WIN then
  vim.o.shell = "pwsh"

  -- Setting shell command flags
  vim.o.shellcmdflag =
    "-NoLogo -NonInteractive -ExecutionPolicy RemoteSigned -Command [Console]::InputEncoding=[Console]::OutputEncoding=[System.Text.UTF8Encoding]::new();$PSDefaultParameterValues['Out-File:Encoding']='utf8';$PSStyle.OutputRendering='plaintext';Remove-Alias -Force -ErrorAction SilentlyContinue tee;"

  -- Setting shell redirection
  vim.o.shellredir = '2>&1 | %%{ "$_" } | Out-File %s; exit $LastExitCode'

  -- Setting shell pipe
  vim.o.shellpipe = '2>&1 | %%{ "$_" } | tee %s; exit $LastExitCode'

  -- Setting shell quote options
  vim.o.shellquote = ""
  vim.o.shellxquote = ""
end

vim.g.mapleader = " "
vim.g.bigfile_size = 1.5 * 1024 * 1024 --- 1.5MB
vim.g.qf_disable_statusline = true

vim.opt.mouse:append("a")
vim.opt.shortmess:append({ W = true, I = true, c = true, C = true }) --Don't show the intro message when starting nvim
vim.opt.fillchars:append(eve.icon.fillchars)
vim.opt.listchars:append(eve.icon.listchars)

vim.o.foldcolumn = "0"
vim.o.foldenable = true
vim.o.foldlevel = 99
vim.o.foldlevelstart = 99
vim.o.laststatus = 3 -- Keep only the global status bar.
vim.o.showtabline = 2

---! appearance
vim.o.autoindent = true
vim.o.autowrite = true
vim.o.backspace = table.concat({ "indent", "eol", "start" }, ",")
vim.o.breakindent = true
vim.o.colorcolumn = "100,120"
vim.o.conceallevel = 0 -- Disable conceal.
vim.o.cursorline = true -- highlight the row of the cursor.
vim.o.cursorlineopt = "number,screenline"
vim.o.cursorcolumn = false -- true to highlight the column of the cursor.
vim.o.expandtab = true -- use spaces instead of tabs
vim.o.guifont = "Maple Mono NF CN"
vim.o.linebreak = true -- Wrap lines at convenient points
vim.o.list = true -- Show some invisible characters (tabs...
vim.o.number = true -- Print line number
vim.o.pumblend = 10 -- Popup blend
vim.o.pumheight = 10 -- Maximum number of entries in a popup
vim.o.relativenumber = true
vim.o.scrolloff = 4 -- Lines of context
vim.o.shiftround = true -- Round indent
vim.o.shiftwidth = 2
vim.o.showmode = false -- Dont show mode since we have a statusline
vim.o.sidescrolloff = 8 -- Columns of context
vim.o.smartindent = true -- Insert indents automatically
vim.o.smarttab = true
vim.o.smoothscroll = true
vim.o.softtabstop = 2 -- set the tab width
vim.o.syntax = "off"
vim.o.tabstop = 2 -- set the tab width
vim.o.termguicolors = true
vim.o.timeout = true
vim.o.timeoutlen = vim.g.vscode and 1000 and 300 -- Lower than default (1000) to quickly trigger which-key
vim.o.winborder = "rounded"
vim.o.winminwidth = 10 -- Minimum window width
vim.o.wrap = false

---! diff
vim.o.diffopt = table.concat({
  "algorithm:histogram",
  "closeoff",
  "context:0",
  "filler",
  "indent-heuristic", -- better indentation diffs
  "internal",
  -- "iwhite", -- ignore whitespace changes
  "linematch:100",
  "vertical",
}, ",")

---! disable some default providers
vim.g.loaded_node_provider = 0
vim.g.loaded_perl_provider = 0
vim.g.loaded_python3_provider = 0
vim.g.loaded_ruby_provider = 0

---! encoding
vim.o.encoding = "utf-8"
vim.o.fileencoding = "utf-8"
vim.o.fileencodings = "utf-8,gbk,latin1"
vim.o.fileformat = "unix"

---! format
vim.o.formatoptions = table.concat({
  --  "c", -- Auto wrap using 'textwidth'
  "r", -- Auto insert comment leader
  "o", -- Auto insert comment leader after "o" or "O"
  "q", -- Allow formatting of comments with "gq"
  "2", -- The second line decides the indent for the paragraph
  "l", -- Long lines are not broken in insert mode
  "j", -- Remove comment leader when joining lines
}, "")

---! panel split
vim.o.splitbelow = true
vim.o.splitright = true
vim.o.splitkeep = "screen"

-- search
vim.o.grepformat = "%f:%l:%c:%m"
vim.o.grepprg = "rg --vimgrep"
vim.o.ignorecase = true
vim.o.smartcase = true -- Don't ignore case with capitals

-- spell
vim.o.spell = false
vim.o.spelllang = "en"

-- misc
vim.o.completeopt = "menuone,noselect,popup"
vim.o.confirm = true -- Confirm to save changes before exiting modified buffer
vim.o.inccommand = "nosplit" -- preview incremental substitute
vim.o.jumpoptions = "view"
vim.o.updatetime = 200 -- Save swap file and trigger CursorHold
vim.o.undofile = true
vim.o.undolevels = 10000
vim.o.virtualedit = "block" -- Allow cursor to move where there is no text in visual block mode
vim.o.wildmode = "longest:full,full" -- Command-line completion mode

vim.o.ruler = false -- Disable the default ruler
vim.g.markdown_recommended_style = 0 -- fix markdown indentation settings
