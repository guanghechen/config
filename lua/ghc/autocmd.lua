--#plugin
vim.cmd([[autocmd User TelescopePreviewerLoaded setlocal number]]) -- enable numbers in telescope preview.
vim.cmd([[highlight def link @text.diff.add DiffAdded]])
vim.cmd([[highlight def link @text.diff.delete DiffRemoved]])
