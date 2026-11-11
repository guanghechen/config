local bootstrap = require("__test__.support.bootstrap")
local harness = require("__test__.support.harness")
local t = harness.new()
local git = require("__test__.support.git")
local workspace = ""
local in_repo = true
t:patch_global("yoz", require("yoz"))
t:patch_global("stl", require("stl"))
local warnings = bootstrap.with_reporter(t).warn
t:patch_table(stl.reporter, "error", function(report)
  error(vim.inspect(report))
end)
t:patch_global("dot", {
  path = {
    workspace = function()
      return workspace
    end,
    is_git_repo = function()
      return in_repo
    end,
    normalize = yoz.canonical_path.normalize,
    dirname = yoz.canonical_path.dirname,
    join = yoz.canonical_path.join,
  },
})
local status = require("era.m.git.status")
local ignore = require("era.m.git.ignore")
local reference = assert(loadfile("__test__/fixtures/era/m/git/ignore_lua_reference.lua"))()

---@return string
local function new_repo()
  local root = git.repo(t)
  workspace = root
  ignore.clear()
  reference.clear_ignored_cache()
  return root
end

t:test("native cache matches the Lua oracle for rules, tracked paths, and literal newlines", function()
  local root = new_repo()
  vim.fn.writefile({ "tracked" }, root .. "/tracked")
  git.run(root, { "add", "tracked" })
  vim.fn.writefile({ "ignored-*", "nested/cache/", "tracked", "line?break" }, root .. "/.gitignore")
  vim.fn.writefile({ "excluded" }, root .. "/.git/info/exclude", "a")
  local paths = {}
  for _, name in ipairs({ "ignored-file", "visible", "nested/cache/file", "tracked", "excluded", "line\nbreak" }) do
    paths[#paths + 1] = root .. "/" .. name
  end
  t.await(ignore.preload(paths))
  t.await(reference.preload_ignored(paths))
  for _, path in ipairs(paths) do
    t.assert_eq(reference.is_ignored(path), ignore.is_ignored(path), "native/Lua ignore parity")
    t.assert_eq(ignore.is_ignored(path), ignore.is_ignored(path .. "/"), "trailing slash identity")
  end
  t.assert_false(ignore.is_ignored(root .. "/tracked"), "tracked paths are not ignored")
  t.assert_true(ignore.is_ignored(root .. "/line\nbreak"), "literal newline retained")
end)

t:test("failed batches publish confirmed matches without caching missing output as false", function()
  local outside = new_repo()
  local root = new_repo()
  vim.fn.writefile({ "ignored", "unknown" }, root .. "/.gitignore")
  local before = #warnings
  t.await(ignore.preload({ root .. "/ignored", outside .. "/file", root .. "/unknown" }))
  t.assert_true(ignore.is_ignored(root .. "/ignored"), "positive result before failure")
  t.assert_false(ignore.is_ignored(root .. "/unknown"), "unread path remains unknown")
  t.assert_eq(before + 1, #warnings, "partial failure reported")
  t.await(ignore.preload({ root .. "/unknown" }))
  t.assert_true(ignore.is_ignored(root .. "/unknown"), "unknown path is retried")
end)

t:test("concurrent completions notify once and invalidation can notify the same paths again", function()
  local root = new_repo()
  vim.fn.writefile({ "ignored" }, root .. "/.gitignore")
  local events = {}
  local subscriber = stl.c.Subscriber.new({
    on_next = function(paths)
      events[#events + 1] = paths
    end,
  })
  local subscription = ignore.o_refreshed:subscribe(subscriber, true)
  t:defer(function()
    subscription:unsubscribe()
    subscriber:dispose()
  end)
  local paths = { root .. "/ignored" }
  local first = ignore.preload(paths)
  local second = ignore.preload(paths)
  t.await(first)
  t.await(second)
  t.wait_until(function()
    return #events == 1
  end, 5000, "one ignore event")
  t.await(ignore.preload(paths))
  t.assert_eq(1, #events, "cache hit emits no event")
  ignore.clear()
  t.await(ignore.preload(paths))
  t.wait_until(function()
    return #events == 2
  end, 5000, "repeat after invalidation")
end)

t:test("invalidation while a request is pending retries and settles its original Future", function()
  local root = new_repo()
  vim.fn.writefile({ "ignored" }, root .. "/.gitignore")
  local future = ignore.preload({ root .. "/ignored" })
  ignore.clear()
  t.await(future)
  t.assert_true(ignore.is_ignored(root .. "/ignored"), "fresh result published")
end)

t:test("root fingerprints invalidate existing cache hits without an editor event", function()
  local root = new_repo()
  local path = root .. "/new"
  t.await(ignore.preload({ path }))
  t.assert_false(ignore.is_ignored(path), "negative cached")
  vim.fn.writefile({ "new" }, root .. "/.gitignore")
  t.await(ignore.preload({ path }))
  t.assert_true(ignore.is_ignored(path), "root ignore fingerprint changed")
  local before = ignore.o_refreshed:snapshot()
  vim.fn.writefile({ "!new" }, root .. "/.gitignore")
  t.await(ignore.preload({ path }))
  t.assert_false(ignore.is_ignored(path), "ignored path became visible")
  t.assert_true(before ~= ignore.o_refreshed:snapshot(), "async negative transition repaints the existing UI")
end)

t:test("a workspace switch suppresses an old cache publication without another query", function()
  local next_root = new_repo()
  local root = new_repo()
  vim.fn.writefile({ "ignored" }, root .. "/.gitignore")
  local before = ignore.o_refreshed:snapshot()
  local future = ignore.preload({ root .. "/ignored" })
  workspace = next_root
  t.await(future)
  t.assert_true(before == ignore.o_refreshed:snapshot(), "old workspace emits no event")
  t.assert_false(ignore.is_ignored(next_root .. "/ignored"), "new workspace has a separate cache")
end)

t:test("native ignore round-trips pathname bytes", function()
  local root = new_repo()
  vim.fn.writefile({ "*" }, root .. "/.gitignore")
  local suffix = package.config:sub(1, 1) == "/" and "\255" or "字"
  local path = root .. "/raw-" .. suffix
  t.await(ignore.preload({ path }))
  t.assert_true(ignore.is_ignored(path), "native byte-key lookup")
  t.assert_eq(path, ignore.o_refreshed:snapshot()[1], "event preserves pathname bytes")
end)

t:test("editor write and focus events invalidate nested ignore changes", function()
  local root = new_repo()
  vim.fn.mkdir(root .. "/nested", "p")
  local path = root .. "/nested/file"
  t.await(ignore.preload({ path }))
  ignore.setup()
  t:defer(function()
    vim.api.nvim_del_augroup_by_name("DotModuleGitIgnore")
  end)
  local bufnr = t:buffer({ "file" }, { name = root .. "/nested/.gitignore", scratch = false })
  vim.api.nvim_buf_call(bufnr, function()
    vim.cmd("silent write")
  end)
  t.await(ignore.preload({ path }))
  t.assert_true(ignore.is_ignored(path), "BufWritePost invalidation")
  vim.fn.writefile({ "!file" }, root .. "/nested/.gitignore")
  vim.api.nvim_exec_autocmds("FocusGained", { group = "DotModuleGitIgnore" })
  t.await(ignore.preload({ path }))
  t.assert_false(ignore.is_ignored(path), "external edit invalidated on focus")
end)

t:test("nested symlink paths inherit the outermost link instead of failing beyond a symlink", function()
  local root = new_repo()
  vim.fn.mkdir(root .. "/target/leaf", "p")
  vim.fn.writefile({ "content" }, root .. "/target/leaf/file")
  vim.fn.writefile({ "link" }, root .. "/.gitignore")
  assert(vim.uv.fs_symlink("target", root .. "/link", { dir = true }))
  assert(vim.uv.fs_symlink("leaf", root .. "/target/inner", { dir = true }))
  local path = root .. "/link/inner/file"
  local before = #warnings
  t.await(reference.preload_ignored({ path }))
  t.assert_false(reference.is_ignored(path), "old inner-link lookup cannot cross outer symlink")
  t.assert_eq(before + 1, #warnings, "old boundary failure reproduced")
  t.await(ignore.preload({ path, root .. "/link/leaf/file" }))
  t.assert_true(ignore.is_ignored(path), "outer link's ignore state")
  t.assert_eq(before + 1, #warnings, "native lookup adds no warning")
end)

t:test("cancellation settles without publishing and precancelled requests do no native work", function()
  local root = new_repo()
  vim.fn.writefile({ "ignored" }, root .. "/.gitignore")
  local token = stl.c.CancellationToken.new()
  local future = ignore.preload({ root .. "/ignored" }, token)
  token:cancel()
  t.await(future)
  t.assert_false(ignore.is_ignored(root .. "/ignored"), "cancelled result not cached")
  t.assert_true(ignore.preload({ root .. "/ignored" }, token):is_done(), "precancelled result is immediate")
end)

t:test("native startup failures reject with diagnostics and missing repositories skip work", function()
  new_repo()
  t:patch_table(yoz.git, "ignore_cache", function()
    error("native start failed")
  end)
  local before = #warnings
  local future = ignore.preload({ workspace .. "/file" })
  t.assert_true(future:is_failed(), "native startup failure rejected")
  t.assert_eq(before + 1, #warnings, "startup failure reported")
  in_repo = false
  t:defer(function()
    in_repo = true
  end)
  t.await(ignore.preload({ workspace .. "/file" }))
  t.assert_false(ignore.is_ignored(workspace .. "/file"), "non-repository lookup")
end)

-- Exit leaves era.m.job rejecting every later run in this process, so this case must stay last.
t:test("shared exit lifecycle cancels both status and ignore jobs", function()
  local root = new_repo()
  vim.fn.writefile({ "ignored" }, root .. "/.gitignore")
  local jobs = require("era.m.job")
  jobs.setup()
  t:defer(function()
    vim.api.nvim_del_augroup_by_name("DotModuleNativeJobs")
  end)
  local preload = ignore.preload({ root .. "/ignored" })
  local collect = status.collect()
  vim.api.nvim_exec_autocmds("VimLeavePre", { group = "DotModuleNativeJobs" })
  t.assert_true(preload:is_done(), "ignore settled during exit")
  t.assert_false(preload:is_failed(), "ignore cancellation retains its nil-result contract")
  t.assert_true(collect:is_failed(), "status cancellation rejects")
  t.assert_false(ignore.is_ignored(root .. "/ignored"), "no exit-time cache publication")
  t.await(ignore.preload({ root .. "/ignored" }))
end)

t:run()
