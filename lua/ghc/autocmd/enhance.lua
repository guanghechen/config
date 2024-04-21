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
