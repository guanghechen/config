if eve.os.is_mac() or eve.os.is_nix() or eve.os.is_wsl() then
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
  local A = eve.path.locate_git_repo(p)
  local B = eve.path.locate_git_repo(cwd)

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

---! Auto resize splits when window got resized.
vim.api.nvim_create_autocmd({ "VimResized" }, {
  callback = function()
    local current_tab = vim.fn.tabpagenr()
    vim.cmd("tabdo wincmd =")
    vim.cmd("tabnext " .. current_tab)
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

---! Highlight on yank.
vim.api.nvim_create_autocmd({ "TextYankPost" }, {
  callback = function()
    vim.highlight.on_yank()
  end,
})

---! Make the buffers not listed.
vim.api.nvim_create_autocmd("FileType", {
  pattern = "qf",
  callback = function()
    vim.opt_local.buflisted = false
  end,
})

---! Show lsp progress.
vim.api.nvim_create_autocmd("LspProgress", {
  callback = function()
    vim.cmd("redrawstatus")
  end,
})
