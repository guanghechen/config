local locations = require("eve.globals.locations")
local mvc = require("eve.globals.mvc")
local widgets = require("eve.globals.widgets")
local constants = require("eve.std.constants")
local ft = require("eve.std.filetype")
local os = require("eve.std.os")
local path = require("eve.std.path")

if os.is_mac() or os.is_nix() or os.is_wsl() then
  vim.opt.shell = "/bin/bash"
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

vim.filetype.add({
  extension = { rasi = "rasi", rofi = "rasi", wofi = "rasi" },
  filename = {
    ["vifmrc"] = "vim",
  },
  pattern = {
    [".*"] = {
      function(filepath, bufnr)
        return vim.bo[bufnr]
            and vim.bo[bufnr].filetype ~= constants.FT_BIGFILE
            and filepath
            and vim.fn.getfsize(filepath) > vim.g.bigfile_size
            and constants.FT_BIGFILE
          or nil
      end,
    },

    ["*.fzfrc"] = "bash",
    ["*.ripgreprc"] = "bash",
    ["*.tmux.conf"] = "tmux",

    ["*.ts"] = "typescript",
    ["*.cts"] = "typescript",
    ["*.mts"] = "typescript",

    ["*.js"] = "javascript",
    ["*.cjs"] = "javascript",
    ["*.mjs"] = "javascript",

    [".*/waybar/config"] = "jsonc",
    [".*/mako/config"] = "dosini",
    [".*/kitty/.+%.conf"] = "bash",
    [".*/hypr/.+%.conf"] = "hyprlang",
    ["%.env%.[%w_.-]+"] = "sh",
  },
})
vim.api.nvim_create_autocmd({ "FileType" }, {
  pattern = "bigfile",
  callback = function(ev)
    vim.schedule(function()
      vim.bo[ev.buf].syntax = vim.filetype.match({ buf = ev.buf }) or ""
    end)
  end,
})

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
