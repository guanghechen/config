local augroup = require("fml.fn.augroup")
local path = require("fml.std.path")

-- Clear jumplist
-- See https://superuser.com/questions/1642954/how-to-start-vim-with-a-clean-jumplist
local function auto_clear_jumps()
  vim.schedule(function()
    vim.cmd("clearjumps")
  end)
end

-- Auto cd the directory:
-- 1. the opend file is under a git repo, let's remember the the git repo path as A, and assume the
--    git repo directory of the shell cwd is B.
--
--    a) If A is different from B, then auto cd the A.
--    b) If A is the same as B, then no action needed.
-- 2. the opened file is not under a git repo, then auto cd the directory of the opened file.
local function auto_change_dir()
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
end

vim.api.nvim_create_autocmd({ "VimEnter" }, {
  group = augroup("startup"),
  callback = function()
    auto_clear_jumps()
    auto_change_dir()
  end,
})
