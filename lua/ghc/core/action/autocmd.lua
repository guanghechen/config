---@class ghc.core.action.autocmd.action
local action = {
  session = require("ghc.core.action.session"),
}

---@class ghc.core.action.autocmd.util
local util = {
  path = require("ghc.core.util.path"),
}

---@class ghc.core.action.autocmd
local M = {}

function M.augroup(name)
  return vim.api.nvim_create_augroup("ghc_" .. name, { clear = true })
end

-- Auto cd the directory:
-- 1. the opend file is under a git repo, let's remember the the git repo path as A, and assume the
--    git repo directory of the shell cwd is B.
--
--    a) If A is different from B, then auto cd the A.
--    b) If A is the same as B, then no action needed.
-- 2. the opened file is not under a git repo, then auto cd the directory of the opened file.

function M.autocmd_change_dir()
  vim.api.nvim_create_autocmd({ "VimEnter" }, {
    group = M.augroup("change_dir"),
    pattern = "*",
    callback = function()
      if vim.fn.expand("%") ~= "" then
        local cwd = vim.uv.cwd()
        local p = vim.fn.expand("%:p:h")

        local A = util.path.findGitRepoFromPath(p)
        local B = util.path.findGitRepoFromPath(cwd)

        if A == nil then
          vim.cmd("cd " .. p .. "")
        elseif A ~= B then
          vim.cmd("cd " .. A .. "")
        end
      end
    end,
  })
end

-- Check if we need to reload the file when it changed
function M.autocmd_checktime()
  vim.api.nvim_create_autocmd({ "FocusGained", "TermClose", "TermLeave" }, {
    group = M.augroup("checktime"),
    callback = function()
      if vim.o.buftype ~= "nofile" then
        vim.cmd("checktime")
      end
    end,
  })
end

-- Clear jumplist
-- See https://superuser.com/questions/1642954/how-to-start-vim-with-a-clean-jumplist
function M.autocmd_clear_jumps()
  vim.api.nvim_create_autocmd({ "VimEnter" }, {
    group = M.augroup("clear_jumps"),
    pattern = "*",
    callback = function()
      vim.cmd("clearjumps")
    end,
  })
end

-- close some filetypes with <q>
---@param opts {pattern: table}
function M.autocmd_close_with_q(opts)
  local function close()
    vim.cmd("close")
  end

  local pattern = opts.pattern
  vim.api.nvim_create_autocmd("FileType", {
    group = M.augroup("close_with_q"),
    pattern = pattern,
    callback = function(event)
      vim.bo[event.buf].buflisted = false
      vim.keymap.set("n", "q", close, { buffer = event.buf, noremap = true, silent = true })
    end,
  })
end

-- Auto create dir when saving a file, in case some intermediate directory does not exist
function M.autocmd_create_dirs()
  vim.api.nvim_create_autocmd({ "BufWritePre" }, {
    group = M.augroup("create_dirs"),
    callback = function(event)
      if event.match:match("^%w%w+:[\\/][\\/]") then
        return
      end
      local file = vim.uv.fs_realpath(event.match) or event.match
      vim.fn.mkdir(vim.fn.fnamemodify(file, ":p:h"), "p")
    end,
  })
end

-- enable spell in text filetypes
---@param opts {pattern: table}
function M.autocmd_enable_spell(opts)
  local pattern = opts.pattern
  vim.api.nvim_create_autocmd("FileType", {
    group = M.augroup("enable_spell"),
    pattern = pattern,
    callback = function()
      vim.opt_local.spell = true
    end,
  })
end

-- enable wrap in text filetypes
---@param opts {pattern: table}
function M.autocmd_enable_wrap(opts)
  local pattern = opts.pattern
  vim.api.nvim_create_autocmd("FileType", {
    group = M.augroup("enable_wrap"),
    pattern = pattern,
    callback = function()
      vim.opt_local.wrap = true
    end,
  })
end

-- go to last loc when opening a buffer
---@param opts {exclude: table}
function M.autocmd_goto_last_location(opts)
  local exclude = opts.exclude
  vim.api.nvim_create_autocmd({ "BufReadPost" }, {
    group = M.augroup("goto_last_loction"),
    callback = function(event)
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
end

-- Highlight on yank
function M.autocmd_highlight_yank()
  vim.api.nvim_create_autocmd({ "TextYankPost" }, {
    group = M.augroup("highlight_yank"),
    callback = function()
      vim.highlight.on_yank()
    end,
  })
end

function M.autocmd_remember_last_tabnr()
  vim.api.nvim_create_autocmd({ "TabLeave" }, {
    group = M.augroup("remember_last_tabnr"),
    callback = function()
      local tabnr_current = vim.api.nvim_get_current_tabpage()
      vim.g.ghc_last_tabnr = tabnr_current
    end,
  })
end

-- resize splits if window got resized
function M.autocmd_resize_splits()
  vim.api.nvim_create_autocmd({ "VimResized" }, {
    group = M.augroup("resize_splits"),
    callback = function()
      local current_tab = vim.fn.tabpagenr()
      vim.cmd("tabdo wincmd =")
      vim.cmd("tabnext " .. current_tab)
    end,
  })
end

function M.autocmd_session_autosave()
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = M.augroup("session_autosave"),
    callback = function()
      action.session.session_autosave()
    end,
  })
end

---@param opts {pattern: table, format?: "unix" | "dos"}
function M.autocmd_set_fileformat(opts)
  local pattern = opts.pattern
  local format = opts.format or "unix"
  vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
    group = M.augroup("set_fileformat"),
    pattern = pattern,
    callback = function()
      vim.api.nvim_buf_set_option(0, "fileformat", format)
    end,
  })
end

-- unlist some buffers with specified filetypes for easier close.
---@param opts {pattern: table}
function M.autocmd_unlist_buffer(opts)
  local pattern = opts.pattern
  vim.api.nvim_create_autocmd("FileType", {
    group = M.augroup("unlist_buffer"),
    pattern = pattern,
    callback = function(event)
      vim.bo[event.buf].buflisted = false
    end,
  })
end

return M
