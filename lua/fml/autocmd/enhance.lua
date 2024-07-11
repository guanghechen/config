local augroup = require("fml.fn.augroup")

-- Auto create dir when saving a file, in case some intermediate directory does not exist
vim.api.nvim_create_autocmd({ "BufWritePre" }, {
  group = augroup("create_dirs"),
  callback = function(event)
    if event.match:match("^%w%w+:[\\/][\\/]") then
      return
    end
    local file = vim.uv.fs_realpath(event.match) or event.match
    vim.fn.mkdir(vim.fn.fnamemodify(file, ":p:h"), "p")
  end,
})

-- Check if we need to reload the file when it changed
vim.api.nvim_create_autocmd({ "FocusGained", "TermClose", "TermLeave" }, {
  group = augroup("checktime"),
  callback = function()
    if vim.o.buftype ~= "nofile" then
      vim.cmd("checktime")
    end
  end,
})

---! Show lsp progress.
vim.api.nvim_create_autocmd("LspProgress", {
  group = augroup("lsp_show_progress"),
  callback = function(args)
    if string.find(args.match, "end") then
      vim.cmd("redrawstatus")
    end
    vim.cmd("redrawstatus")
  end,
})

---! Auto toggle realtive linenumber.
vim.api.nvim_create_autocmd({ "InsertLeave" }, {
  pattern = "*",
  group = augroup("toggle_relative_linenumber"),
  callback = function()
    if vim.o.nu and vim.api.nvim_get_mode().mode == "n" then
      if ghc.context.client.relativenumber:snapshot() then
        vim.opt.relativenumber = true
      end
    end
  end,
})
vim.api.nvim_create_autocmd({ "InsertEnter" }, {
  pattern = "*",
  group = augroup("toggle_relative_linenumber"),
  callback = function()
    if vim.o.nu then
      vim.opt.relativenumber = false
      vim.cmd("redraw")
    end
  end,
})

---! Auto resize splits when window got resized.
vim.api.nvim_create_autocmd({ "VimResized" }, {
  group = augroup("resize_splits"),
  callback = function()
    local current_tab = vim.fn.tabpagenr()
    vim.cmd("tabdo wincmd =")
    vim.cmd("tabnext " .. current_tab)
  end,
})

---! Highlight on yank.
vim.api.nvim_create_autocmd({ "TextYankPost" }, {
  group = augroup("highlight_yank"),
  callback = function()
    vim.highlight.on_yank()
  end,
})
