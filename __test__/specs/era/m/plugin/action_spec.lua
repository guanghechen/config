local bootstrap = require("__test__.support.bootstrap")
local harness = require("__test__.support.harness")

local t = harness.new()
local git = require("__test__.support.git")
local Future = require("stl.c.future")

bootstrap.with_global(t, "stl", {
  async = require("stl.async"),
  c = { Future = Future },
  git = {
    act = {},
    info = require("stl.git.info"),
  },
  reporter = {
    info = function() end,
    warn = function() end,
  },
  shell = {
    get_shell_args = function(command)
      return { "sh", "-c", command }
    end,
  },
})
bootstrap.with_global(t, "yoz", {
  canonical_path = {
    to_os_path = function(path)
      return path
    end,
  },
  path = {
    is_exist = function()
      return false
    end,
  },
})

local State = {
  options = { root = "/plugins" },
  specs = {},
  lock = {},
  load_lock = function() end,
  reload_lock = function() end,
  update_lock = function() end,
}
bootstrap.with_global(t, "dot", {
  path = {
    join = function(...)
      return table.concat({ ... }, "/")
    end,
  },
})
t:patch_table(package.loaded, "era.m.plugin.state", State)

local Action = require("era.m.plugin.action")

local function reset_action()
  t:patch_table(Action, "_running", false)
  t:patch_table(Action, "_action", nil)
  t:patch_table(Action, "_tasks", {})
end

t:test("string build resolves spawn failures", function()
  reset_action()
  t:patch_table(vim, "system", function()
    error("injected spawn failure", 0)
  end)

  ---@diagnostic disable-next-line: missing-fields
  local future = Action.__run_build__({ build = "cargo build --release" }, "/plugin")

  t.assert_true(future:is_resolved(), "spawn failure future")
  local result = future:get_result()
  t.assert_false(result.ok, "spawn failure result")
  t.assert_true(result.err:find("injected spawn failure", 1, true) ~= nil, "spawn failure diagnostic")
end)

t:test("build releases state after an unexpected rejection", function()
  reset_action()
  t:patch_table(package.loaded, "era.m.plugin.loader", {
    get = function()
      return { spec = { name = "blink.cmp", build = "cargo build --release" } }
    end,
  })
  t:patch_table(Action, "__run_build__", function()
    return Future.reject("unexpected build rejection")
  end)

  local progress_count = 0
  local future = Action.build("blink.cmp", function()
    progress_count = progress_count + 1
  end)

  t.assert_true(future:is_resolved(), "build should consume worker rejection")
  t.assert_false(Action.is_running(), "build lock")
  t.assert_eq("error", Action.get_tasks()["blink.cmp"].status, "task status")
  t.assert_true(
    Action.get_tasks()["blink.cmp"].message:find("unexpected build rejection", 1, true) ~= nil,
    "task diagnostic"
  )
  t.assert_eq(2, progress_count, "progress notifications")
end)

t:test("clean reports inline task progress and retains its result", function()
  reset_action()
  t:patch_table(State, "collect_orphan_plugins", function()
    return { "unused.nvim" }
  end)
  t:patch_table(State, "remove_orphan_lock_entries", function() end)
  t:patch_table(Action, "__rm_recursive__", function()
    return true
  end)

  local progress_count = 0
  local future = Action.clean(function()
    progress_count = progress_count + 1
  end)

  t.assert_true(future:is_resolved(), "clean future")
  t.assert_false(Action.is_running(), "clean lock")
  t.assert_eq("done", Action.get_tasks()["unused.nvim"].status, "clean task status")
  t.assert_eq("Removed", Action.get_tasks()["unused.nvim"].message, "clean task message")
  t.assert_eq(2, progress_count, "clean progress notifications")
end)

t:test("non-zero string build preserves the last streamed diagnostic", function()
  reset_action()
  t:patch_table(vim, "system", function(_, opts, callback)
    opts.stderr(nil, "first diagnostic\nblink-build-diagnostic\n")
    callback({ code = 1, stderr = nil })
    return {}
  end)

  local task = {}
  ---@diagnostic disable-next-line: missing-fields
  local future = Action.__run_build__({ build = "cargo build --release" }, "/plugin", task)
  t.wait_until(function()
    return future:is_done()
  end, 5000, "build callback")

  t.assert_true(future:is_resolved(), "non-zero future")
  local result = future:get_result()
  t.assert_false(result.ok, "non-zero result")
  t.assert_eq("blink-build-diagnostic", result.err, "final diagnostic")
  t.assert_eq(2, #task.output, "bounded output")
  t.assert_eq("blink-build-diagnostic", task.output[2], "streamed diagnostic")
end)

t:test("lazy job scheduler starts only the concurrency window", function()
  reset_action()
  local started = 0
  local resolvers = {} ---@type (fun(result: any): nil)[]
  local jobs = {} ---@type (fun(): stl.c.Future)[]

  for index = 1, 10 do
    jobs[index] = function()
      started = started + 1
      local future, resolve = Future.new_with_resolver()
      resolvers[index] = resolve
      return future
    end
  end

  local aggregate = Action.__throttle_jobs__(jobs)
  t.assert_eq(8, started, "initial concurrency")
  t.assert_false(aggregate:is_done(), "aggregate before completion")

  resolvers[1](nil)
  t.assert_eq(9, started, "first queued job")
  resolvers[2](nil)
  t.assert_eq(10, started, "second queued job")
  for index = 3, 10 do
    resolvers[index](nil)
  end
  t.assert_true(aggregate:is_resolved(), "aggregate completion")
end)

t:test("plugin jobs settle after a post-await worker failure", function()
  reset_action()
  t:patch_table(State, "specs", { { name = "async-error.nvim" } })
  t:patch_table(Action, "__install_single_plugin__", function()
    Future.new(function(resolve)
      vim.schedule(function()
        resolve(nil)
      end)
    end):await()
    error("injected post-await failure", 0)
  end)

  local future = Action.install()
  t.wait_until(function()
    return future:is_done()
  end, 5000, "post-await failure")

  t.assert_true(future:is_resolved(), "aggregate completion")
  t.assert_false(Action.is_running(), "action lock")
  local task = Action.get_tasks()["async-error.nvim"]
  t.assert_eq("error", task.status, "task status")
  t.assert_eq("injected post-await failure", task.message, "task message")
  t.assert_true(task.output ~= nil and task.output[1] == "stack traceback:", "task traceback")
  for _, line in ipairs(task.output or {}) do
    t.assert_true(line:find("\n", 1, true) == nil, "single-line task output")
  end
end)

t:test("sync marks unpinned specs without rewriting the lock", function()
  reset_action()
  local pinned = { name = "pinned.nvim" }
  local unpinned = { name = "unpinned.nvim" }
  local invalid = { name = "invalid.nvim" }
  local abbreviated = { name = "abbreviated.nvim" }
  local pinned_commit = string.rep("a", 40)
  t:patch_table(State, "specs", { pinned, unpinned, invalid, abbreviated })
  t:patch_table(State, "lock", {
    [pinned.name] = { branch = "main", commit = pinned_commit },
    [invalid.name] = { branch = "main", commit = "not-a-commit" },
    [abbreviated.name] = { branch = "main", commit = "abcdef0" },
  })
  local lock_writes = 0
  local lock_reloads = 0
  t:patch_table(State, "reload_lock", function()
    lock_reloads = lock_reloads + 1
  end)
  t:patch_table(State, "update_lock", function()
    lock_writes = lock_writes + 1
  end)
  t:patch_table(Action, "__sync_single_plugin__", function(_, task, lock)
    t.assert_eq(pinned_commit, lock.commit, "locked commit")
    task.status = "done"
    task.message = "Synced"
  end)

  local future = Action.sync()
  t.assert_true(future:is_resolved(), "sync future")
  t.assert_false(Action.is_running(), "sync lock")
  t.assert_eq("done", Action.get_tasks()[pinned.name].status, "pinned status")
  t.assert_eq("error", Action.get_tasks()[unpinned.name].status, "unpinned status")
  t.assert_eq("Unpinned", Action.get_tasks()[unpinned.name].message, "unpinned message")
  t.assert_eq("Invalid lock entry", Action.get_tasks()[invalid.name].message, "invalid lock message")
  t.assert_eq("Invalid lock entry", Action.get_tasks()[abbreviated.name].message, "abbreviated lock message")
  t.assert_eq(1, lock_reloads, "lock reloads")
  t.assert_eq(0, lock_writes, "lock writes")
end)

t:test("sync rejects non-table lock entries without leaking the action lock", function()
  reset_action()
  local invalid = { name = "invalid.nvim" }
  t:patch_table(State, "specs", { invalid })
  t:patch_table(State, "lock", { [invalid.name] = 7 })

  local ok, future = pcall(Action.sync)

  t.assert_true(ok, "sync call")
  t.assert_true(future:is_resolved(), "sync future")
  t.assert_false(Action.is_running(), "action lock")
  t.assert_eq("error", Action.get_tasks()[invalid.name].status, "task status")
  t.assert_eq("Invalid lock entry", Action.get_tasks()[invalid.name].message, "task message")
end)

t:test("sync splits multiline clone failures into render-safe task fields", function()
  reset_action()
  t:patch_table(yoz.path, "is_exist", function()
    return false
  end)
  t:patch_table(stl.git.act, "clone", function()
    return Future.resolve({
      ok = false,
      stdout = "",
      stderr = "Cloning into 'plugin'...\nfatal: Remote branch missing not found\n",
    })
  end)

  local task = Action.__new_task__("clone-error.nvim", "sync")
  task.status = "running"
  stl.async.run(function()
    Action.__sync_single_plugin__({ name = "clone-error.nvim" }, task, {
      branch = "missing",
      commit = string.rep("a", 40),
    })
  end)

  t.assert_eq("error", task.status, "task status")
  t.assert_eq("Clone failed: Cloning into 'plugin'...", task.message, "task message")
  t.assert_eq("fatal: Remote branch missing not found", task.output[1], "task detail")
  for _, line in ipairs(task.output) do
    t.assert_true(line:find("\n", 1, true) == nil, "single-line task output")
  end
end)

t:test("sync refuses to checkout a dirty installed plugin", function()
  reset_action()
  local fetches = 0
  local checkouts = 0
  t:patch_table(yoz.path, "is_exist", function()
    return true
  end)
  t:patch_table(stl.git.info, "info", function()
    return { branch = "main", commit = string.rep("1", 40) }
  end)
  t:patch_table(Action, "__git_is_dirty__", function()
    return Future.resolve({ ok = true, dirty = true, err = nil })
  end)
  t:patch_table(Action, "__git_fetch__", function()
    fetches = fetches + 1
    return Future.resolve({ ok = true, err = nil })
  end)
  t:patch_table(Action, "__git_checkout__", function()
    checkouts = checkouts + 1
    return Future.resolve({ ok = true, err = nil })
  end)

  local task = Action.__new_task__("dirty.nvim", "sync")
  task.status = "running"
  stl.async.run(function()
    Action.__sync_single_plugin__({ name = "dirty.nvim" }, task, { branch = "main", commit = string.rep("2", 40) })
  end)

  t.assert_eq("error", task.status, "dirty status")
  t.assert_eq("Dirty worktree", task.message, "dirty message")
  t.assert_eq(0, fetches, "dirty fetches")
  t.assert_eq(0, checkouts, "dirty checkouts")
end)

t:test("sync checks dirtiness when the installed commit already matches the lock", function()
  reset_action()
  local target = string.rep("1", 40)
  local dirty_checks = 0
  t:patch_table(yoz.path, "is_exist", function()
    return true
  end)
  t:patch_table(stl.git.info, "info", function()
    return { branch = "main", commit = target }
  end)
  t:patch_table(Action, "__git_is_dirty__", function()
    dirty_checks = dirty_checks + 1
    return Future.resolve({ ok = true, dirty = true, err = nil })
  end)

  local task = Action.__new_task__("dirty-at-lock.nvim", "sync")
  task.status = "running"
  stl.async.run(function()
    Action.__sync_single_plugin__({ name = "dirty-at-lock.nvim" }, task, { branch = "main", commit = target })
  end)

  t.assert_eq(1, dirty_checks, "dirty checks")
  t.assert_eq("error", task.status, "dirty status")
  t.assert_eq("Dirty worktree", task.message, "dirty message")
end)

t:test("sync builds a newly cloned plugin already at the locked commit", function()
  reset_action()
  local target = string.rep("a", 40)
  local builds = 0
  local checkouts = 0
  t:patch_table(yoz.path, "is_exist", function()
    return false
  end)
  t:patch_table(stl.git.act, "clone", function()
    return Future.resolve({ ok = true, stdout = "", stderr = "" })
  end)
  t:patch_table(stl.git.info, "info", function()
    return { branch = "main", commit = target }
  end)
  t:patch_table(Action, "__git_checkout__", function()
    checkouts = checkouts + 1
    return Future.resolve({ ok = true, err = nil })
  end)
  t:patch_table(Action, "__fetch_commits__", function()
    return Future.resolve({})
  end)

  local task = Action.__new_task__("built.nvim", "sync")
  task.status = "running"
  stl.async.run(function()
    Action.__sync_single_plugin__({
      name = "built.nvim",
      build = function()
        builds = builds + 1
      end,
    }, task, { branch = "main", commit = target })
  end)

  t.assert_eq("done", task.status, task.message)
  t.assert_eq("Synced", task.message, "sync message")
  t.assert_eq(1, builds, "build count")
  t.assert_eq(0, checkouts, "redundant checkout")
end)

---@class __test__.specs.era.m.plugin.action.IRepository
---@field public root                   string A temporary directory holding the others.
---@field public remote                 string A bare repository.
---@field public source                 string A work tree on `main` that pushes to `remote` as `origin`.
---@field public plugins                string The plugin root, which the plugin state finds on disk until the case ends.

---@return __test__.specs.era.m.plugin.action.IRepository
local function repository()
  local root = t:tempdir()
  local repo = { root = root, remote = root .. "/remote.git", source = root .. "/source", plugins = root .. "/plugins" }
  vim.fn.mkdir(repo.source, "p")
  vim.fn.mkdir(repo.plugins, "p")
  git.run(root, { "init", "--bare", repo.remote })
  git.run(repo.source, { "init", "-b", "main" })
  git.run(repo.source, { "remote", "add", "origin", repo.remote })
  t:patch_table(State.options, "root", repo.plugins)
  t:patch_table(yoz.path, "is_exist", function(path)
    return vim.uv.fs_stat(path) ~= nil
  end)
  return repo
end

---Installs the plugin `name` as a clone of `url` on `main`, given `options` before the branch.
---@param repo                          __test__.specs.era.m.plugin.action.IRepository
---@param name                          string
---@param url                           string
---@param options                       string[]
---@return string
local function install(repo, name, url, options)
  local plugin = repo.plugins .. "/" .. name
  -- Clones need their own identity for checkout reflogs, avoiding hostname/email discovery.
  local args = { "clone", "--config", "user.name=Plugin Test", "--config", "user.email=plugin-test@example.test" }
  vim.list_extend(args, options)
  vim.list_extend(args, { "--branch", "main", url, plugin })
  git.run(repo.root, args)
  return plugin
end

---Syncs the installed plugin `name` to `lock` and waits until the sync ends.
---@param name                          string
---@param lock                          table
---@param msg                           string
---@return table
local function sync_installed(name, lock, msg)
  local task = Action.__new_task__(name, "sync")
  task.status = "running"
  stl.async.run(function()
    Action.__sync_single_plugin__({ name = name }, task, lock)
  end)
  t.wait_until(function()
    return task.status ~= "running"
  end, 5000, msg)
  return task
end

t:test("sync checks out the exact locked commit in a clean repository", function()
  reset_action()
  local repo = repository()
  vim.fn.writefile({ "one" }, repo.source .. "/plugin.txt")
  git.run(repo.source, { "add", "plugin.txt" })
  git.run(repo.source, { "commit", "-m", "first" })
  local first = vim.trim(git.run(repo.source, { "rev-parse", "HEAD" }))
  vim.fn.writefile({ "two" }, repo.source .. "/plugin.txt")
  git.run(repo.source, { "commit", "-am", "second" })
  local second = vim.trim(git.run(repo.source, { "rev-parse", "HEAD" }))
  git.run(repo.source, { "push", "-u", "origin", "main" })
  local plugin = install(repo, "exact.nvim", repo.remote, {})

  local task = sync_installed("exact.nvim", { branch = "main", commit = first }, "sync exact commit")

  t.assert_eq("done", task.status, task.message)
  t.assert_eq("Synced", task.message, "sync message")
  t.assert_eq(first, vim.trim(git.run(plugin, { "rev-parse", "HEAD" })), "checked out commit")
  t.assert_true(first ~= second, "test commits")
end)

t:test("sync fetches a lock branch outside the installed single-branch refspec", function()
  reset_action()
  local repo = repository()
  vim.fn.writefile({ "base" }, repo.source .. "/plugin.txt")
  git.run(repo.source, { "add", "plugin.txt" })
  git.run(repo.source, { "commit", "-m", "base" })
  git.run(repo.source, { "branch", "stable" })
  vim.fn.writefile({ "main" }, repo.source .. "/plugin.txt")
  git.run(repo.source, { "commit", "-am", "main-only" })
  git.run(repo.source, { "switch", "stable" })
  vim.fn.writefile({ "stable" }, repo.source .. "/plugin.txt")
  git.run(repo.source, { "commit", "-am", "stable-only" })
  local stable = vim.trim(git.run(repo.source, { "rev-parse", "HEAD" }))
  git.run(repo.source, { "push", "origin", "main", "stable" })
  local plugin = install(repo, "branch.nvim", "file://" .. repo.remote, { "--single-branch" })

  local missing = vim.system({ "git", "cat-file", "-e", stable .. "^{commit}" }, { cwd = plugin }):wait()
  t.assert_true(missing.code ~= 0, "locked branch commit should not exist before sync")

  local task = sync_installed("branch.nvim", { branch = "stable", commit = stable }, "sync lock branch")

  t.assert_eq("done", task.status, task.message)
  t.assert_eq("Synced", task.message, "sync message")
  t.assert_eq(stable, vim.trim(git.run(plugin, { "rev-parse", "HEAD" })), "checked out lock branch commit")
end)

t:run()
