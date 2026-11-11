require("ark.bootstrap").setup()
local t = require("__test__.support.harness").new()
local bootstrap = require("__test__.support.bootstrap")
local diffview = require("__test__.support.diffview")
local fs = require("__test__.support.fs")
local treeview = require("__test__.support.treeview")
local changes = require("era.m.diffview.pane.changes")
local action = require("era.m.diffview.view.workspace.action")
local Jobs = require("era.m.filetree.jobs")
local Future = require("stl.c.future")
local paths = require("ux.filetree.path")

---@param names                         string[]
---@return table
local function fixture(names)
  local directory = paths.from_os(t:tempdir())
  t:patch_table(dot.path, "workspace", function()
    return directory
  end)
  t:patch_table(era.m.git.state, "refresh", function() end)
  local reports = bootstrap.with_reporter(t).error
  local entries = {}
  for _, name in ipairs(names) do
    entries[#entries + 1] = { filepath = name, stage_type = "unstaged", status = "?" }
  end
  local owner, pane = diffview.changes_pane(t, entries, { stage_type = "unstaged", viewtype = "list" }, true)
  vim.api.nvim_win_set_cursor(pane.winnr, { assert(changes.find_entry_line(pane.bufnr, entries[1])), 0 })
  local state = {
    disposed = false,
    refreshed = 0,
    is_disposed = function(self)
      return self.disposed
    end,
    request_refresh = function(self)
      if not self.disposed then
        self.refreshed = self.refreshed + 1
      end
    end,
  }
  return {
    directory = directory,
    path = directory .. "/" .. names[1],
    bufnr = pane.bufnr,
    winnr = pane.winnr,
    owner = owner,
    entries = entries,
    reports = reports,
    state = state,
    context = diffview.workspace_context({ state = state }),
  }
end

t:test("untracked discard uses a real native Job and preserves a modified buffer", function()
  local name = stl.env.IS_WIN and "untracked.txt" or "back\\slash.txt"
  local f = fixture({ name })
  vim.fn.writefile({ "disk" }, f.path)
  local bufnr = t:buffer({ "unsaved" }, { name = f.path, listed = true })
  local ok, result = t.settle(action.reset(f.context))
  t.assert_true(ok, result)
  t.assert_true(result.success, result.error)
  t.assert_eq(f.path, result.items[1].source)
  t.assert_nil(vim.uv.fs_lstat(f.path))
  t.assert_eq("unsaved", vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)[1])
  t.assert_true(vim.api.nvim_get_option_value("modified", { buf = bufnr }))
  t.assert_eq(1, f.state.refreshed)
  t.assert_eq(0, #f.reports)
  t.assert_false(Jobs.pending())
end)

t:test("pending discard keeps its captured path across cursor and workspace changes and coalesces repeats", function()
  local f = fixture({ "first.txt", "second.txt" })
  vim.fn.writefile({ "first" }, f.path)
  vim.fn.writefile({ "second" }, f.directory .. "/second.txt")
  fs.write(f.directory .. "/other/first.txt", { "other" })
  local captured = treeview.await(Jobs.capture(f.path))
  local waiting, resolve = Future.new_with_resolver()
  local captures = 0
  t:patch_table(Jobs, "capture", function(path)
    captures = captures + 1
    t.assert_eq(f.path, path)
    return waiting
  end)
  local first = action.reset(f.context)
  t.assert_true(first == action.reset(f.context))
  vim.api.nvim_win_set_cursor(f.winnr, { assert(changes.find_entry_line(f.bufnr, f.entries[2])), 0 })
  t:patch_table(dot.path, "workspace", function()
    return f.directory .. "/other"
  end)
  resolve(captured)
  local ok, result = t.settle(first)
  t.assert_true(ok, result)
  t.assert_true(result.success, result.error)
  t.assert_eq(1, captures)
  t.assert_nil(vim.uv.fs_lstat(f.path))
  t.assert_eq("second", vim.fn.readfile(f.directory .. "/second.txt")[1])
  t.assert_eq("other", vim.fn.readfile(f.directory .. "/other/first.txt")[1])
  t.assert_eq(1, f.state.refreshed)
end)

t:test(
  "replacing a captured entry preserves both resources and a later explicit retry can discard the replacement",
  function()
    local f = fixture({ "file.txt" })
    vim.fn.writefile({ "original" }, f.path)
    local captured = treeview.await(Jobs.capture(f.path))
    local waiting, resolve = Future.new_with_resolver()
    local restore = t:patch_table(Jobs, "capture", function()
      return waiting
    end)
    local future = action.reset(f.context)
    assert(vim.uv.fs_rename(f.path, f.path .. ".old"))
    vim.fn.writefile({ "replacement" }, f.path)
    resolve(captured)
    local ok, result = t.settle(future)
    t.assert_true(ok, result)
    t.assert_false(result.success)
    t.assert_eq("replacement", vim.fn.readfile(f.path)[1])
    t.assert_eq("original", vim.fn.readfile(f.path .. ".old")[1])
    t.assert_eq(0, f.state.refreshed)
    t.assert_eq(1, #f.reports)
    restore()
    ok, result = t.settle(action.reset(f.context))
    t.assert_true(ok, result)
    t.assert_true(result.success, result.error)
    t.assert_nil(vim.uv.fs_lstat(f.path))
    t.assert_eq(1, f.state.refreshed)
  end
)

t:test("a failed capture releases the request for a later explicit retry", function()
  local f = fixture({ "missing.txt" })
  local ok = t.settle(action.reset(f.context))
  t.assert_false(ok)
  t.assert_eq(1, #f.reports)
  t.assert_eq(0, f.state.refreshed)
  vim.fn.writefile({ "new" }, f.path)
  local result
  ok, result = t.settle(action.reset(f.context))
  t.assert_true(ok, result)
  t.assert_true(result.success, result.error)
  t.assert_nil(vim.uv.fs_lstat(f.path))
end)

t:test("discard does not recursively remove an ordinary directory", function()
  local f = fixture({ "folder" })
  fs.write(f.path .. "/child.txt", { "keep" })
  local ok, error = t.settle(action.reset(f.context))
  t.assert_false(ok)
  t.assert_eq("Discard does not delete directories", error)
  t.assert_eq("keep", vim.fn.readfile(f.path .. "/child.txt")[1])
  t.assert_eq(1, #f.reports)
  t.assert_eq(0, f.state.refreshed)
end)

t:test("discard removes a directory symlink without following it", function()
  if stl.env.IS_WIN then
    t.skip("needs Unix directory symlinks")
  end
  local f = fixture({ "link" })
  fs.write(f.directory .. "/target/child.txt", { "keep" })
  assert(vim.uv.fs_symlink("target", f.path))
  local ok, result = t.settle(action.reset(f.context))
  t.assert_true(ok, result)
  t.assert_true(result.success, result.error)
  t.assert_nil(vim.uv.fs_lstat(f.path))
  t.assert_eq("keep", vim.fn.readfile(f.directory .. "/target/child.txt")[1])
  t.assert_eq(1, f.state.refreshed)
end)

t:test("closing the workspace while capture is pending suppresses the late Job", function()
  local f = fixture({ "keep.txt" })
  vim.fn.writefile({ "keep" }, f.path)
  local captured = treeview.await(Jobs.capture(f.path))
  local waiting, resolve = Future.new_with_resolver()
  t:patch_table(Jobs, "capture", function()
    return waiting
  end)
  local future = action.reset(f.context)
  f.state.disposed = true
  f.owner:dispose()
  resolve(captured)
  local ok, result = t.settle(future)
  t.assert_true(ok)
  t.assert_nil(result)
  t.assert_eq("keep", vim.fn.readfile(f.path)[1])
  t.assert_eq(0, f.state.refreshed)
  t.assert_eq(0, #f.reports)
  t.assert_false(Jobs.pending())
end)

t:test("an accepted Job completes after its workspace closes without refreshing disposed UI", function()
  local f = fixture({ "file.txt" })
  vim.fn.writefile({ "delete" }, f.path)
  local run = Jobs.run
  t:patch_table(Jobs, "run", function(data, plan)
    local future = run(data, plan)
    f.state.disposed = true
    f.owner:dispose()
    return future
  end)
  local ok, result = t.settle(action.reset(f.context))
  t.assert_true(ok, result)
  t.assert_true(result.success, result.error)
  t.assert_nil(vim.uv.fs_lstat(f.path))
  t.assert_eq(0, f.state.refreshed)
  t.assert_eq(0, #f.reports)
  t.assert_false(Jobs.pending())
end)

t:test("cancellation without completed IO preserves the file without reporting a deletion failure", function()
  local f = fixture({ "keep.txt" })
  vim.fn.writefile({ "keep" }, f.path)
  t:patch_table(Jobs, "run", function()
    return Future.resolve({ items = {}, status = { cancelled = true }, success = false })
  end)
  local ok, result = t.settle(action.reset(f.context))
  t.assert_true(ok, result)
  t.assert_true(result.status.cancelled)
  t.assert_eq("keep", vim.fn.readfile(f.path)[1])
  t.assert_eq(0, f.state.refreshed)
  t.assert_eq(0, #f.reports)
end)

t:test("completed IO with a synchronization error refreshes the pane and reports the separate failure", function()
  local f = fixture({ "file.txt" })
  vim.fn.writefile({ "delete" }, f.path)
  local run = Jobs.run
  t:patch_table(Jobs, "run", function(data, plan)
    return run(data, plan):map(function(result)
      result.items[1].sync_error = { code = "Stale", message = "source changed after IO" }
      return result
    end)
  end)
  local ok, result = t.settle(action.reset(f.context))
  t.assert_true(ok, result)
  t.assert_true(result.success, result.error)
  t.assert_nil(vim.uv.fs_lstat(f.path))
  t.assert_eq(1, f.state.refreshed)
  t.assert_eq(1, #f.reports)
  t.assert_eq("source changed after IO", f.reports[1].details.error)
  t.assert_true(f.reports[1].message:find("synchronization failed", 1, true) ~= nil)
end)

t:test("a Job completion error cannot hide an already completed delete or its error", function()
  local f = fixture({ "file.txt" })
  vim.fn.writefile({ "delete" }, f.path)
  local run = Jobs.run
  t:patch_table(Jobs, "run", function(data, plan)
    return run(data, plan):map(function(result)
      result.success = false
      result.error = "job completion failed"
      return result
    end)
  end)
  local ok, result = t.settle(action.reset(f.context))
  t.assert_true(ok, result)
  t.assert_false(result.success)
  t.assert_nil(vim.uv.fs_lstat(f.path))
  t.assert_eq(1, f.state.refreshed)
  t.assert_eq(1, #f.reports)
  t.assert_eq("job completion failed", f.reports[1].details.error)
end)

t:test("cancellation after completed IO still refreshes the deleted file", function()
  local f = fixture({ "file.txt" })
  vim.fn.writefile({ "delete" }, f.path)
  local run = Jobs.run
  t:patch_table(Jobs, "run", function(data, plan)
    return run(data, plan):map(function(result)
      result.success = false
      result.status.cancelled = true
      return result
    end)
  end)
  local ok, result = t.settle(action.reset(f.context))
  t.assert_true(ok, result)
  t.assert_true(result.status.cancelled)
  t.assert_nil(vim.uv.fs_lstat(f.path))
  t.assert_eq(1, f.state.refreshed)
  t.assert_eq(0, #f.reports)
end)

t:run()
