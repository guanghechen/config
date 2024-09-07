local constants = require("eve.globals.constants")
local mvc = require("eve.globals.mvc")
local widgets = require("eve.globals.widgets")
local os = require("eve.std.os")
local path = require("eve.std.path")
local tmux = require("eve.std.tmux")

if os.is_mac() or os.is_nix() or os.is_wsl() then
  vim.opt.shell = "/bin/bash"
end

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

---! Watch the zen mode change on tmux.
if vim.env.TMUX then
  local function on_resize()
    local is_tmux_pane_zoomed = tmux.is_tmux_pane_zoomed() ---@type boolean
    mvc.tmux_zen_mode:next(is_tmux_pane_zoomed)
  end

  on_resize()
  vim.api.nvim_create_autocmd({ "VimResized" }, {
    callback = on_resize,
  })
end

vim.api.nvim_create_autocmd("VimLeavePre", {
  once = true,
  callback = function()
    mvc.dispose()
  end,
})

---! Set the filetype
vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
  pattern = { "*.tmux.conf" },
  callback = function()
    vim.bo.filetype = "tmux"
  end,
})
vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
  pattern = { "*.fzfrc", "*.ripgreprc" },
  callback = function()
    vim.bo.filetype = "bash"
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

    local filetype = vim.bo[bufnr].filetype
    if
      filetype == "gitcommit"
      or filetype == constants.FT_TERM
      or filetype == constants.FT_NEOTREE
      or filetype == constants.FT_SEARCH_INPUT
      or filetype == constants.FT_SEARCH_MAIN
      or filetype == constants.FT_SEARCH_PREVIEW
    then
      return
    end

    local mark = vim.api.nvim_buf_get_mark(bufnr, '"')
    local lcount = vim.api.nvim_buf_line_count(bufnr)
    if mark[1] > 0 and mark[1] <= lcount then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})

vim.api.nvim_create_autocmd({ "BufWinEnter" }, {
  callback = function()
    local winnr = vim.api.nvim_get_current_win() ---@type integer
    local win_config = vim.api.nvim_win_get_config(winnr) ---@type vim.api.keyset.win_config
    if win_config.relative == nil or win_config.relative == "" then
      local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
      local filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string
      local dirpath = vim.fn.expand("%:p:h") ---@type string
      widgets.set_current(bufnr, dirpath, filepath)
    end
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

---! Close some filetypes with <q>
vim.api.nvim_create_autocmd("FileType", {
  pattern = {
    "checkhealth",
    "git",
    "help",
    "lspinfo",
    "neotest-output",
    "neotest-output-panel",
    "neotest-summary",
    "neo-tree",
    "notify",
    "PlenaryTestPopup",
    "qf",
    "startuptime",
    "tsplayground",
    "Trouble",
  },
  callback = function(event)
    vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = event.buf, noremap = true, silent = true })
  end,
})

---! Enable code spell
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "gitcommit", "html", "lua", "text", "typescript" },
  callback = function()
    vim.opt_local.spell = true
  end,
})

---! Enable wrap.
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "markdown", "text" },
  callback = function()
    local winnr = vim.api.nvim_get_current_win() ---@type integer
    local wincfg = vim.api.nvim_win_get_config(winnr) ---@type vim.api.keyset.win_config
    if wincfg.relative == nil or wincfg.relative == "" then
      vim.opt_local.wrap = true
    end
  end,
})

---! Make the buffers not listed.
vim.api.nvim_create_autocmd("FileType", {
  pattern = "qf",
  callback = function()
    vim.opt_local.buflisted = false
  end,
})

---! Set the tab width
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "markdown" },
  callback = function()
    vim.opt.shiftwidth = 2
    vim.opt.softtabstop = 2 -- set the tab width
    vim.opt.tabstop = 2 -- set the tab width
  end,
})

---! Unlist some buffers with specified filetypes for easier close.
vim.api.nvim_create_autocmd("FileType", {
  pattern = {
    "checkhealth",
    "git",
    "help",
    "lspinfo",
    "man",
    "neotest-output",
    "neotest-output-panel",
    "neotest-summary",
    "neo-tree",
    "notify",
    "PlenaryTestPopup",
    "qf",
    "startuptime",
    "tsplayground",
    "Trouble",
  },
  callback = function(event)
    vim.bo[event.buf].buflisted = false
  end,
})

---! Check if we need to reload the file when it changed
vim.api.nvim_create_autocmd({ "FocusGained" }, {
  callback = function()
    if vim.o.buftype ~= "nofile" then
      vim.cmd("checktime")
    end
  end,
})

---! Show lsp progress.
vim.api.nvim_create_autocmd("LspProgress", {
  callback = function()
    vim.cmd("redrawstatus")
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
    local current_tab = vim.fn.tabpagenr()
    vim.cmd("tabdo wincmd =")
    vim.cmd("tabnext " .. current_tab)

    widgets.resize()
  end,
})
