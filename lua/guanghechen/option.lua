-- appearance
vim.opt.relativenumber = ghc.context.shared.relativenumber:get_snapshot()

---format
vim.o.formatexpr = "v:lua.require'conform'.formatexpr()" -- better format: https://github.com/stevearc/conform.nvim/issues/372#issuecomment-2066778074
vim.opt.formatoptions = table.concat({
  --  "c", -- Auto wrap using 'textwidth'
  "r", -- Auto insert comment leader
  "o", -- Auto insert comment leader after "o" or "O"
  "q", -- Allow formatting of comments with "gq"
  "2", -- The second line decides the indent for the paragraph
  "l", -- Long lines are not broken in insert mode
  "j", -- Remove comment leader when joining lines
}, "")
