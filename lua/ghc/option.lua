local function list(items, sep)
  return table.concat(items, sep or ",")
end

----------------------------------------------------------------------------------------------------

-- clipboard
vim.g.clipboard = fml.clipboard.get_clipboard()

-- mouse
vim.opt.mouse:append("a")

-- diff
vim.opt.diffopt = list({
  "algorithm:histogram",
  "closeoff",
  "context:0",
  "filler",
  "indent-heuristic",
  "internal",
  "iwhite",
  "linematch:100",
  "vertical",
})

-- panel split
vim.opt.splitbelow = true
vim.opt.splitright = true
vim.opt.splitkeep = "screen"

-- appearance
vim.opt.autoindent = true
vim.opt.autowrite = true
vim.opt.backspace = list({ "indent", "eol", "start" })
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
vim.opt.foldenable = true
vim.opt.foldexpr = "v:lua.require'ghc.core.action.fold'.foldexpr()"
vim.opt.foldlevel = 99
vim.opt.foldmethod = "expr"
vim.opt.foldtext = ""
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
vim.opt.laststatus = 3 -- Keep only the global status bar.
vim.opt.lazyredraw = false -- Close since this could make the `folke/noice.nvim` experience issues.
vim.opt.number = true -- Print line number
vim.opt.pumblend = 10 -- Popup blend
vim.opt.pumheight = 10 -- Maximum number of entries in a popup
vim.opt.relativenumber = fml.context.shared.relativenumber:get_snapshot()
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
vim.opt.statuscolumn = [[%!v:lua.require'ghc.core.action.ui_statuscolumn'.statuscolumn()]]
vim.opt.tabstop = 2 -- set the tab width
vim.opt.termguicolors = true
vim.opt.timeoutlen = vim.g.vscode and 1000 and 300 -- Lower than default (1000) to quickly trigger which-key
vim.opt.winminwidth = 10 -- Minimum window width
vim.opt.wrap = false

---format
vim.o.formatexpr = "v:lua.require'conform'.formatexpr()" -- better format: https://github.com/stevearc/conform.nvim/issues/372#issuecomment-2066778074
vim.opt.formatoptions = list({
  --  "c", -- Auto wrap using 'textwidth'
  "r", -- Auto insert comment leader
  "o", -- Auto insert comment leader after "o" or "O"
  "q", -- Allow formatting of comments with "gq"
  "2", -- The second line decides the indent for the paragraph
  "l", -- Long lines are not broken in insert mode
  "j", -- Remove comment leader when joining lines
}, "")

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
