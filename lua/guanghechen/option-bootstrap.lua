vim.g.mapleader = " "
vim.g.clipboard = fml.clipboard.get_clipboard()

vim.opt.foldenable = true
vim.opt.foldexpr = "v:lua._G.fml.fn.foldexpr()"
vim.opt.foldlevel = 99
vim.opt.foldmethod = "expr"
vim.opt.foldtext = ""
vim.opt.laststatus = 3 -- Keep only the global status bar.
vim.opt.showtabline = 2
vim.opt.statusline = "%!v:lua._G.ghc.ui.statusline.render()"
vim.opt.tabline = "%!v:lua._G.ghc.ui.tabline.render()"

vim.opt.mouse:append("a")
vim.opt.shortmess:append("I") --Don't show the intro message when starting nvim

---! appearance
vim.opt.autoindent = true
vim.opt.autowrite = true
vim.opt.backspace = table.concat({ "indent", "eol", "start" }, ",")
vim.opt.breakindent = true
vim.opt.colorcolumn = { 100, 120 }
vim.opt.conceallevel = 0 -- Disable conceal.
vim.opt.cursorline = true -- ggtrue to highlight the row of the cursor.
vim.opt.cursorlineopt = "number,screenline"
vim.opt.cursorcolumn = false -- true to highlight the column of the cursor.
vim.opt.expandtab = true -- use spaces instead of tabs
vim.opt.fillchars = {
  diff = "╱",
  eob = " ",
  foldopen = "",
  foldclose = "",
  fold = " ",
  foldsep = " ",
  msgsep = "─",
  vert = "│",
}
vim.opt.guifont = { "RobotoMono Nerd Font" }
vim.opt.list = true -- Show some invisible characters (tabs...
vim.opt.listchars:append({
  eol = "↲",
  extends = "»",
  lead = "·",
  nbsp = "·",
  precedes = "«",
  space = "·",
  tab = " ",
  trail = "•",
})
vim.opt.lazyredraw = false -- Close since this could make the `folke/noice.nvim` experience issues.
vim.opt.number = true -- Print line number
vim.opt.pumblend = 10 -- Popup blend
vim.opt.pumheight = 10 -- Maximum number of entries in a popup
vim.opt.relativenumber = ghc.context.client.relativenumber:get_snapshot()
vim.opt.scrolloff = 4 -- Lines of context
vim.opt.shiftround = true -- Round indent
vim.opt.shiftwidth = 2
vim.opt.showmode = false -- Dont show mode since we have a statusline
vim.opt.sidescrolloff = 8 -- Columns of context
vim.opt.signcolumn = "yes"
vim.opt.smartindent = true -- Insert indents automatically
vim.opt.smarttab = true
vim.opt.smoothscroll = true
vim.opt.softtabstop = 2 -- set the tab width
vim.opt.statuscolumn = "%!v:lua._G.fml.statuscolumn.statuscolumn()"
vim.opt.tabstop = 2 -- set the tab width
vim.opt.termguicolors = true
vim.opt.timeoutlen = vim.g.vscode and 1000 and 300 -- Lower than default (1000) to quickly trigger which-key
vim.opt.winminwidth = 10 -- Minimum window width
vim.opt.wrap = false

---! diff
vim.opt.diffopt = table.concat({
  "algorithm:histogram",
  "closeoff",
  "context:0",
  "filler",
  "indent-heuristic",
  "internal",
  "iwhite",
  "linematch:100",
  "vertical",
}, ",")

---! disable some default providers
vim.g.loaded_node_provider = 0
vim.g.loaded_perl_provider = 0
vim.g.loaded_python3_provider = 0
vim.g.loaded_ruby_provider = 0

---! encoding
vim.opt.fileencoding = "utf-8"
vim.opt.fileformat = "unix"
vim.opt_global.fileencodings = "utf-8"

---! format
vim.opt.formatoptions = table.concat({
  --  "c", -- Auto wrap using 'textwidth'
  "r", -- Auto insert comment leader
  "o", -- Auto insert comment leader after "o" or "O"
  "q", -- Allow formatting of comments with "gq"
  "2", -- The second line decides the indent for the paragraph
  "l", -- Long lines are not broken in insert mode
  "j", -- Remove comment leader when joining lines
}, "")

---! panel split
vim.opt.splitbelow = true
vim.opt.splitright = true
vim.opt.splitkeep = "screen"

-- search
vim.opt.grepformat = "%f:%l:%c:%m"
vim.opt.grepprg = "rg --vimgrep"
vim.opt.ignorecase = true
vim.opt.smartcase = true -- Don't ignore case with capitals

-- misc
vim.opt.confirm = true -- Confirm to save changes before exiting modified buffer
vim.opt.spelllang = { "en" }
vim.opt.updatetime = 200 -- Save swap file and trigger CursorHold
vim.opt.undofile = true
vim.opt.undolevels = 10000
vim.opt.virtualedit = "block" -- Allow cursor to move where there is no text in visual block mode
vim.opt.wildmode = "longest:full,full" -- Command-line completion mode
