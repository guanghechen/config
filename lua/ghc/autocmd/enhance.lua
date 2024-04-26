local path = require("ghc.core.util.path")
local augroup = require("ghc.core.util.autocmd").augroup

-- Clear jumplist
-- See https://superuser.com/questions/1642954/how-to-start-vim-with-a-clean-jumplist
vim.api.nvim_create_autocmd({ "VimEnter" }, {
  group = augroup("clearjumps"),
  pattern = "*",
  callback = function()
    vim.cmd("clearjumps")
  end,
})

-- Auto cd the directory:
-- 1. the opend file is under a git repo, let's remember the the git repo path as A, and assume the
--    git repo directory of the shell cwd is B.
--
--    a) If A is different from B, then auto cd the A.
--    b) If A is the same as B, then no action needed.
-- 2. the opened file is not under a git repo, then auto cd the directory of the opened file.
vim.api.nvim_create_autocmd({ "VimEnter" }, {
  group = augroup("auto_cd"),
  pattern = "*",
  callback = function()
    if vim.fn.expand("%") ~= "" then
      local cwd = vim.uv.cwd()
      local p = vim.fn.expand("%:p:h")

      local A = path.findGitRepoFromPath(p)
      local B = path.findGitRepoFromPath(cwd)

      if A == nil then
        vim.cmd("cd " .. p .. "")
      elseif A ~= B then
        vim.cmd("cd " .. A .. "")
      end
    end
  end,
})

-- Auto create dir when saving a file, in case some intermediate directory does not exist
vim.api.nvim_create_autocmd({ "BufWritePre" }, {
  group = augroup("auto_create_dir"),
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

-- Highlight on yank
vim.api.nvim_create_autocmd({ "TextYankPost" }, {
  group = augroup("highlight_yank"),
  callback = function()
    vim.highlight.on_yank()
  end,
})

-- resize splits if window got resized
vim.api.nvim_create_autocmd({ "VimResized" }, {
  group = augroup("resize_splits"),
  callback = function()
    local current_tab = vim.fn.tabpagenr()
    vim.cmd("tabdo wincmd =")
    vim.cmd("tabnext " .. current_tab)
  end,
})

-- go to last loc when opening a buffer
vim.api.nvim_create_autocmd({ "BufReadPost" }, {
  group = augroup("last_loc"),
  callback = function(event)
    local exclude = { "gitcommit" }
    local buf = event.buf
    if vim.tbl_contains(exclude, vim.bo[buf].filetype) or vim.b[buf].lazyvim_last_loc then
      return
    end
    vim.b[buf].lazyvim_last_loc = true
    local mark = vim.api.nvim_buf_get_mark(buf, '"')
    local lcount = vim.api.nvim_buf_line_count(buf)
    if mark[1] > 0 and mark[1] <= lcount then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})

-- close some filetypes with <q>
vim.api.nvim_create_autocmd("FileType", {
  group = augroup("close_with_q"),
  pattern = {
    "checkhealth",
    "help",
    "lspinfo",
    "neotest-output",
    "neotest-output-panel",
    "neotest-summary",
    "notify",
    "PlenaryTestPopup",
    "qf",
    "query",
    "spectre_panel",
    "startuptime",
    "TelescopePrompt",
    "term",
    "tsplayground",
  },
  callback = function(event)
    vim.bo[event.buf].buflisted = false
    vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = event.buf, silent = true })
  end,
})

-- make it easier to close man-files when opened inline
vim.api.nvim_create_autocmd("FileType", {
  group = augroup("man_unlisted"),
  pattern = { "man" },
  callback = function(event)
    vim.bo[event.buf].buflisted = false
  end,
})

-- check for spell in text filetypes
vim.api.nvim_create_autocmd("FileType", {
  group = augroup("wrap_spell"),
  pattern = { "gitcommit", "html", "lua", "text", "typescript" },
  callback = function()
    vim.opt_local.spell = true
  end,
})
