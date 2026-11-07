-- After $VIMRUNTIME/ftplugin/markdown.vim, which resets 'comments' and drops "r" and "o" from 'formatoptions': with
-- them, <CR> and o continue a list item or a quote.
vim.opt_local.backupcopy = "yes"
vim.opt_local.formatoptions:append("rot")
vim.opt_local.linebreak = true
vim.opt_local.shiftwidth = 2
vim.opt_local.softtabstop = 2
vim.opt_local.tabstop = 2
vim.opt_local.textwidth = 0
vim.opt_local.wrap = true
vim.opt_local.wrapmargin = 0
vim.opt_local.comments = {
  "n:>",
  "b:-",
  "b:*",
  "n:1.",
}
