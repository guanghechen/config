--- Run with: nvim -l __test__/run.lua __test__/specs/era/m/git/watcher_spec.lua
---@diagnostic disable: undefined-global

local bootstrap = require("__test__.support.bootstrap")
local harness = require("__test__.support.harness")

local t = harness.new("era.m.git.watcher")
local head_refreshes = 0 ---@type integer

bootstrap.with_runtime(t, {
  dot = {
    path = {
      dirname = vim.fs.dirname,
      join = function(from, to)
        return from .. "/" .. to
      end,
    },
  },
  era = {
    m = {
      git = {
        blame = {
          clear_failed = function() end,
          invalidate_all = function() end,
        },
        buffer = {
          get_repo = function()
            return nil
          end,
          invalidate_compare_text_all = function()
            head_refreshes = head_refreshes + 1
          end,
          invalidate_index_all = function() end,
          mark_dirty_all = function() end,
        },
        state = {
          clear_ignored_cache = function() end,
          refresh = function() end,
          refresh_index = function() end,
        },
      },
    },
  },
  yoz = {
    path = {
      is_descendant = function(from, to)
        return to == from or vim.startswith(to, from .. "/")
      end,
    },
  },
})

local watcher = require("era.m.git.watcher")

---@param repo                          string
---@param ...                           string
---@return vim.SystemCompleted
local function git(repo, ...)
  return vim.system({ "git", "-C", repo, ... }, { text = true }):wait()
end

---@param branch                        string|nil
---@param pack_refs                     boolean|nil
---@return nil
local function assert_commit_detected(branch, pack_refs)
  local repo = vim.fn.tempname() ---@type string
  vim.fn.mkdir(repo, "p")
  t:defer(function()
    watcher.dispose()
    vim.fn.delete(repo, "rf")
  end)

  git(repo, "init", "-q")
  git(repo, "config", "user.email", "test@test")
  git(repo, "config", "user.name", "test")
  vim.fn.writefile({ "base" }, repo .. "/f.txt")
  git(repo, "add", "f.txt")
  git(repo, "commit", "-qm", "base")
  if branch then
    git(repo, "checkout", "-qb", branch)
  end
  if pack_refs then
    git(repo, "pack-refs", "--all", "--prune")
  end

  head_refreshes = 0
  watcher.update(repo .. "/.git")
  vim.fn.writefile({ "changed" }, repo .. "/f.txt")
  git(repo, "add", "f.txt")
  local committed = git(repo, "commit", "-qm", "change")
  t.assert_eq(0, committed.code, "git commit")

  t.wait_until(function()
    return head_refreshes > 0
  end, 3000, "HEAD ref update should refresh buffers")
end

t:test("watcher observes commits on a top-level branch", function()
  assert_commit_detected(nil)
end)

t:test("watcher observes commits on a nested branch", function()
  assert_commit_detected("feature/nested", true)
end)

t:test("watcher follows HEAD when checkout changes the current ref", function()
  local repo = vim.fn.tempname() ---@type string
  vim.fn.mkdir(repo, "p")
  t:defer(function()
    watcher.dispose()
    vim.fn.delete(repo, "rf")
  end)

  git(repo, "init", "-q")
  git(repo, "config", "user.email", "test@test")
  git(repo, "config", "user.name", "test")
  vim.fn.writefile({ "base" }, repo .. "/f.txt")
  git(repo, "add", "f.txt")
  git(repo, "commit", "-qm", "base")
  watcher.update(repo .. "/.git")

  head_refreshes = 0
  git(repo, "checkout", "-qb", "feature/switched")
  t.wait_until(function()
    return head_refreshes > 0
  end, 3000, "checkout should refresh HEAD")

  head_refreshes = 0
  vim.fn.writefile({ "changed" }, repo .. "/f.txt")
  git(repo, "add", "f.txt")
  git(repo, "commit", "-qm", "change")
  t.wait_until(function()
    return head_refreshes > 0
  end, 3000, "new branch commit should refresh HEAD")
end)

t:test("watcher observes commits from a linked worktree", function()
  local root = vim.fn.tempname() ---@type string
  local repo = root .. "/main" ---@type string
  local worktree = root .. "/worktree" ---@type string
  vim.fn.mkdir(repo, "p")
  t:defer(function()
    watcher.dispose()
    vim.fn.delete(root, "rf")
  end)

  git(repo, "init", "-q")
  git(repo, "config", "user.email", "test@test")
  git(repo, "config", "user.name", "test")
  vim.fn.writefile({ "base" }, repo .. "/f.txt")
  git(repo, "add", "f.txt")
  git(repo, "commit", "-qm", "base")
  local added = git(repo, "worktree", "add", "-qb", "feature/worktree", worktree)
  t.assert_eq(0, added.code, "create worktree")

  local gitdir = vim.trim(git(worktree, "rev-parse", "--absolute-git-dir").stdout or "") ---@type string
  head_refreshes = 0
  watcher.update(gitdir, repo .. "/.git")
  vim.fn.writefile({ "changed" }, worktree .. "/f.txt")
  git(worktree, "add", "f.txt")
  git(worktree, "commit", "-qm", "change")

  t.wait_until(function()
    return head_refreshes > 0
  end, 3000, "worktree ref update should refresh HEAD")
end)

t:run()
