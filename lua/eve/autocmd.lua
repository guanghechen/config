local locations = require("eve.globals.locations")
local mvc = require("eve.globals.mvc")
local widgets = require("eve.globals.widgets")
local ft = require("eve.std.filetype")
local std_os = require("eve.std.os")
local path = require("eve.std.path")

if std_os.is_mac() or std_os.is_nix() or std_os.is_wsl() then
  vim.opt.shell = "/bin/bash"
end

if std_os.is_mac() then
  local im = require("eve.std.im")
  local previous_mode = nil ---@type t.eve.e.VimMode|nil
  vim.api.nvim_create_autocmd({ "ModeChanged" }, {
    callback = function()
      local current_mode = vim.fn.mode() ---@type t.eve.e.VimMode|nil
      if previous_mode == "i" and current_mode == "n" then
        im.set_input_method("English")
      end
      previous_mode = current_mode
    end,
  })
end

if not vim.g.vscode then
  ---! Auto cd the directory:
  ---! 1. the opend file is under a git repo, let's remember the the git repo path as A,
  ---!    and assume the git repo directory of the shell cwd is B.
  ---!      a) If A is different from B, then auto cd the A.
  ---!      b) If A is the same as B, then no action needed.
  ---! 2. the opened file is not under a git repo, then auto cd the directory of the opened file.
  if vim.fn.expand("%") ~= "" then
    local cwd = vim.fn.getcwd()
    local p = vim.fn.expand("%:p:h")
    local A = path.locate_git_repo(p)
    local B = path.locate_git_repo(cwd)

    if A == nil then
      vim.cmd("cd " .. p .. "")
    elseif A ~= B then
      vim.cmd("cd " .. A .. "")
    end
  end

  ---! Clear jumplist. See https://superuser.com/questions/1642954/how-to-start-vim-with-a-clean-jumplist
  vim.schedule(function()
    vim.cmd("clearjumps")
  end)
end

vim.api.nvim_create_autocmd("VimLeavePre", {
  once = true,
  callback = function()
    mvc.dispose()
  end,
})

---! Auto create dirs when saving a file, in case some intermediate directory does not exist
vim.api.nvim_create_autocmd({ "BufWritePre" }, {
  callback = function(event)
    if event.match:match("^%w%w+:[\\/][\\/]") then
      return
    end
    local file = vim.uv.fs_realpath(event.match) or event.match
    vim.fn.mkdir(vim.fn.fnamemodify(file, ":p:h"), "p")
  end,
})

---! Go to last loc when opening a buffer
vim.api.nvim_create_autocmd({ "BufReadPost" }, {
  callback = function(event)
    local bufnr = event.buf ---@type integer
    if vim.b[bufnr].eve_last_loc then
      return
    end
    vim.b[bufnr].eve_last_loc = true

    local filetype = vim.bo[bufnr].filetype ---@type string
    if eve.filetype.is_plain_file(filetype) then
      local mark = vim.api.nvim_buf_get_mark(bufnr, '"')
      local lcount = vim.api.nvim_buf_line_count(bufnr)
      if mark[1] > 0 and mark[1] <= lcount then
        pcall(vim.api.nvim_win_set_cursor, 0, mark)
      end
    end
  end,
})

vim.api.nvim_create_autocmd({ "WinEnter", "BufWinEnter" }, {
  callback = function()
    local winnr = vim.api.nvim_get_current_win() ---@type integer
    local win_config = vim.api.nvim_win_get_config(winnr) ---@type vim.api.keyset.win_config
    if win_config.relative == nil or win_config.relative == "" then
      local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer

      local filetype = vim.bo[bufnr].filetype
      if ft.is_plain_file(filetype) then
        locations.set_current_bufnr(bufnr)
        locations.set_current_winnr(winnr)
      end
    end
  end,
})

---! Close some filetypes with q
vim.api.nvim_create_autocmd("FileType", {
  pattern = ft.get_quitable_with_q_filetypes(),
  callback = function(event)
    local bufnr = event.buf ---@type integer|nil
    if bufnr ~= nil then
      vim.bo[bufnr].buflisted = false
      local function action()
        vim.cmd.close()
        pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
      end
      vim.keymap.set("n", "q", action, { buffer = bufnr, silent = true, desc = "buffer: quit" })
    end
  end,
})

---! Check if we need to reload the file when it changed
vim.api.nvim_create_autocmd({ "FocusGained", "TermClose", "TermLeave" }, {
  callback = function()
    if vim.o.buftype ~= "nofile" then
      vim.cmd.checktime()
    end
  end,
})

---! Highlight on yank.
vim.api.nvim_create_autocmd({ "TextYankPost" }, {
  callback = function()
    vim.highlight.on_yank()
  end,
})

---! Auto resize splits when window got resized.
vim.api.nvim_create_autocmd({ "VimResized" }, {
  callback = function()
    local current_tab = vim.fn.tabpagenr() ---@type integer
    vim.cmd("tabdo wincmd =")
    vim.cmd("tabnext " .. current_tab)
    widgets.resize()
  end,
})
