local __mods = {
  blame = "dot.module.git.blame",
  browse = "dot.module.git.browse",
  buffer = "dot.module.git.buffer",
  cmd = "dot.module.git.cmd",
  diff = "dot.module.git.diff",
  hunk = "dot.module.git.hunk",
  repo = "dot.module.git.repo",
  sign = "dot.module.git.sign",
  state = "dot.module.git.state",
  status = "dot.module.git.status",
  watcher = "dot.module.git.watcher",
}

---@class dot.module.git
---@field public blame                  dot.module.git.blame
---@field public browse                 dot.module.git.browse
---@field public buffer                 dot.module.git.buffer
---@field public cmd                    dot.module.git.cmd
---@field public diff                   dot.module.git.diff
---@field public hunk                   dot.module.git.hunk
---@field public repo                   dot.module.git.repo
---@field public sign                   dot.module.git.sign
---@field public state                  dot.module.git.state
---@field public status                 dot.module.git.status
---@field public watcher                dot.module.git.watcher
---@field public get_branch             fun(): string
---@field public show_hunk              fun(): nil
---@field public toggle_blame           fun(): nil
---@field public open_in_browser        fun(opts: { what: string|nil }|nil): nil
local M = setmetatable({}, {
  __index = function(t, k)
    local m = __mods[k]
    if m then
      local loaded = require(m)
      rawset(t, k, loaded)
      return loaded
    end
    return rawget(t, k)
  end,
})

local augroup = vim.api.nvim_create_augroup("DotModuleGit", { clear = true })

local function init_watcher()
  if not dot.path.is_git_repo() then
    return
  end

  local workspace = dot.path.workspace()
  M.repo.new(workspace, function(r)
    if r then
      M.state.o_branch:next(r.abbrev_head)
      M.watcher.update(r.gitdir)
      M.state.refresh_async()
    end
  end)
end

vim.schedule(init_watcher)

vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile" }, {
  group = augroup,
  callback = function(args)
    M.buffer.attach(args.buf)
  end,
})

vim.api.nvim_create_autocmd("BufWritePost", {
  group = augroup,
  callback = function(args)
    M.buffer.refresh(args.buf, true)
  end,
})

vim.api.nvim_create_autocmd("BufDelete", {
  group = augroup,
  callback = function(args)
    M.buffer.detach(args.buf)
  end,
})

vim.api.nvim_create_autocmd("VimLeavePre", {
  group = augroup,
  callback = function()
    M.watcher.dispose()
  end,
})

for _, buf in ipairs(vim.api.nvim_list_bufs()) do
  if vim.api.nvim_buf_is_loaded(buf) and vim.api.nvim_buf_is_valid(buf) then
    M.buffer.attach(buf)
  end
end

---@return string
function M.get_branch()
  return M.state.get_branch()
end

---@type dot.module.board.GitHunk|nil
local hunk_board = nil

function M.show_hunk()
  if hunk_board and hunk_board:isvisible() then
    hunk_board:close()
    return
  end

  if hunk_board then
    hunk_board:dispose()
  end

  local bufnr = vim.api.nvim_get_current_buf()
  hunk_board = dot.board.GitHunk.new({ bufnr = bufnr })
  hunk_board:open()
end

function M.toggle_blame()
  M.blame.inline_toggle()
end

---@param opts                       { what: string|nil }|nil
function M.open_in_browser(opts)
  M.browse.open(opts)
end

return M
