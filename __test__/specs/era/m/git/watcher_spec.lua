local bootstrap = require("__test__.support.bootstrap")
local harness = require("__test__.support.harness")

local t = harness.new()
local git = require("__test__.support.git")
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
        ignore = {
          clear = function() end,
        },
        state = {
          refresh = function() end,
          refresh_index = function() end,
        },
        user = {
          refresh = function() end,
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

-- FSEvents starts its stream on another thread after the watch is set up and misses the changes before that: write
-- HEAD again, as it is, until the watch reports it. Each write waits out the refresh debounce, which a later event
-- would restart.
---@param gitdir                        string
---@return nil
local function await_watch(gitdir)
  local head = gitdir .. "/HEAD" ---@type string
  local content = vim.fn.readfile(head, "b") ---@type string[]
  head_refreshes = 0
  for _ = 1, 6 do
    vim.fn.writefile(content, head, "b")
    if vim.wait(500, function()
      return head_refreshes > 0
    end, 10) then
      head_refreshes = 0
      return
    end
  end
  error("the watch reports no change")
end

---@param branch                        string|nil
---@param pack_refs                     boolean|nil
---@return nil
local function assert_commit_detected(branch, pack_refs)
  local repo = git.repo(t)
  t:defer(function()
    watcher.dispose()
  end)

  vim.fn.writefile({ "base" }, repo .. "/f.txt")
  git.run(repo, { "add", "f.txt" })
  git.run(repo, { "commit", "-qm", "base" })
  if branch then
    git.run(repo, { "checkout", "-qb", branch })
  end
  if pack_refs then
    git.run(repo, { "pack-refs", "--all", "--prune" })
  end

  watcher.update(repo .. "/.git")
  await_watch(repo .. "/.git")
  vim.fn.writefile({ "changed" }, repo .. "/f.txt")
  git.run(repo, { "add", "f.txt" })
  git.run(repo, { "commit", "-qm", "change" })

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
  local repo = git.repo(t)
  t:defer(function()
    watcher.dispose()
  end)

  vim.fn.writefile({ "base" }, repo .. "/f.txt")
  git.run(repo, { "add", "f.txt" })
  git.run(repo, { "commit", "-qm", "base" })
  watcher.update(repo .. "/.git")
  await_watch(repo .. "/.git")

  git.run(repo, { "checkout", "-qb", "feature/switched" })
  t.wait_until(function()
    return head_refreshes > 0
  end, 3000, "checkout should refresh HEAD")

  head_refreshes = 0
  vim.fn.writefile({ "changed" }, repo .. "/f.txt")
  git.run(repo, { "add", "f.txt" })
  git.run(repo, { "commit", "-qm", "change" })
  t.wait_until(function()
    return head_refreshes > 0
  end, 3000, "new branch commit should refresh HEAD")
end)

t:test("watcher observes commits from a linked worktree", function()
  local repo = git.repo(t)
  local worktree = t:tempdir() .. "/worktree" ---@type string
  t:defer(function()
    watcher.dispose()
  end)

  vim.fn.writefile({ "base" }, repo .. "/f.txt")
  git.run(repo, { "add", "f.txt" })
  git.run(repo, { "commit", "-qm", "base" })
  git.run(repo, { "worktree", "add", "-qb", "feature/worktree", worktree })

  local gitdir = vim.trim(git.run(worktree, { "rev-parse", "--absolute-git-dir" })) ---@type string
  watcher.update(gitdir, repo .. "/.git")
  await_watch(gitdir)
  vim.fn.writefile({ "changed" }, worktree .. "/f.txt")
  git.run(worktree, { "add", "f.txt" })
  git.run(worktree, { "commit", "-qm", "change" })

  t.wait_until(function()
    return head_refreshes > 0
  end, 3000, "worktree ref update should refresh HEAD")
end)

t:test("commits on branches beside the current one leave the watcher quiet", function()
  local repo = git.repo(t)
  local worktrees = t:tempdir()
  t:defer(function()
    watcher.dispose()
  end)

  git.run(repo, { "commit", "--allow-empty", "-qm", "base" })
  -- Worktrees of one user keep their branches side by side in one ref directory.
  git.run(repo, { "worktree", "add", "-qb", "user/current", worktrees .. "/current" })
  git.run(repo, { "worktree", "add", "-qb", "user/sibling", worktrees .. "/sibling" })

  local gitdir = vim.trim(git.run(worktrees .. "/current", { "rev-parse", "--absolute-git-dir" })) ---@type string
  watcher.update(gitdir, repo .. "/.git")
  await_watch(gitdir)
  git.run(worktrees .. "/sibling", { "commit", "--allow-empty", "-qm", "sibling" })
  vim.wait(1000)
  t.assert_eq(0, head_refreshes, "refreshes after a commit on the sibling branch")

  git.run(worktrees .. "/current", { "commit", "--allow-empty", "-qm", "current" })
  t.wait_until(function()
    return head_refreshes > 0
  end, 3000, "a commit on the current branch should refresh HEAD")
end)

t:test("the watcher still follows the current ref after gc packs it and removes its directory", function()
  local repo = git.repo(t)
  t:defer(function()
    watcher.dispose()
  end)
  git.run(repo, { "commit", "--allow-empty", "-qm", "base" })
  git.run(repo, { "checkout", "-qb", "user/current" })

  watcher.update(repo .. "/.git")
  await_watch(repo .. "/.git")
  git.run(repo, { "pack-refs", "--all", "--prune" })
  t.assert_eq(0, vim.fn.isdirectory(repo .. "/.git/refs/heads/user"), "the ref directory is gone")
  vim.wait(500)

  head_refreshes = 0
  git.run(repo, { "commit", "--allow-empty", "-qm", "after gc" })
  t.wait_until(function()
    return head_refreshes > 0
  end, 3000, "a commit after gc should refresh HEAD")
end)

t:test("a ref update clears ignore results once per refresh, not once per file event", function()
  local repo = git.repo(t)
  t:defer(function()
    watcher.dispose()
  end)
  git.run(repo, { "commit", "--allow-empty", "-qm", "base" })
  local clears = 0 ---@type integer
  t:patch_table(era.m.git.ignore, "clear", function()
    clears = clears + 1
  end)

  watcher.update(repo .. "/.git")
  await_watch(repo .. "/.git")
  clears = 0
  git.run(repo, { "commit", "--allow-empty", "-qm", "change" })
  t.wait_until(function()
    return head_refreshes > 0
  end, 3000, "a commit should refresh HEAD")
  vim.wait(500)
  t.assert_eq(head_refreshes, clears, "ignore clears")
end)

for _, failure in ipairs({ "start", "callback" }) do
  t:test("watcher polls refs and index after fs_event " .. failure .. " failure", function()
    local repo = git.repo(t)
    t:defer(function()
      watcher.dispose()
    end)
    vim.fn.writefile({ "base" }, repo .. "/f.txt")
    git.run(repo, { "add", "f.txt" })
    git.run(repo, { "commit", "-qm", "base" })
    git.run(repo, { "checkout", "-qb", "feature/polled" })
    git.run(repo, { "pack-refs", "--all", "--prune" })

    local callbacks = {}
    local closed = 0
    t:patch_table(vim.uv, "new_fs_event", function()
      local closing = false
      return {
        start = function(_, _, _, callback)
          callbacks[#callbacks + 1] = callback
          if failure == "start" then
            return nil, "ENOSYS"
          end
          return 0
        end,
        stop = function() end,
        close = function()
          closing = true
          closed = closed + 1
        end,
        is_closing = function()
          return closing
        end,
      }
    end)
    local timers = {}
    local new_timer = vim.uv.new_timer
    t:patch_table(vim.uv, "new_timer", function()
      local timer = assert(new_timer())
      timers[#timers + 1] = timer
      return timer
    end)
    local index_refreshes = 0
    t:patch_table(era.m.git.buffer, "invalidate_index_all", function()
      index_refreshes = index_refreshes + 1
    end)

    head_refreshes = 0
    watcher.update(repo .. "/.git")
    if failure == "callback" then
      callbacks[1]("ENOSYS")
    end
    t.wait_until(function()
      return head_refreshes > 0 and index_refreshes > 0
    end, 3000, "polling initial metadata snapshot")
    t.assert_true(closed > 0, "failed fs_event handles are closed")

    head_refreshes, index_refreshes = 0, 0
    vim.fn.writefile({ "changed" }, repo .. "/f.txt")
    git.run(repo, { "add", "f.txt" })
    git.run(repo, { "commit", "-qm", "change" })
    t.wait_until(function()
      return head_refreshes > 0 and index_refreshes > 0
    end, 3000, "polling detects ref creation and index replacement")

    head_refreshes = 0
    git.run(repo, { "checkout", "-qb", "feature/next" })
    t.wait_until(function()
      return head_refreshes > 0
    end, 3000, "polling follows the new HEAD ref")
    head_refreshes = 0
    git.run(repo, { "commit", "--allow-empty", "-qm", "next" })
    t.wait_until(function()
      return head_refreshes > 0
    end, 3000, "polling observes subsequent commits")

    watcher.dispose()
    for _, timer in ipairs(timers) do
      t.assert_true(timer:is_closing(), "dispose closes polling and debounce timers")
    end
  end)
end

t:run()
