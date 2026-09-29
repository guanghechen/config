---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.specs.era.m.explorer.selection" ---@type string

local fixture = require("__test__.support.explorer").new("era.m.explorer.selection")
local t, await = fixture.t, fixture.await
local Task = require("ux.treeview.task")
local jobs = require("era.m.explorer.jobs")

---@return table
local function selected_directory()
  local path = fixture.directory()
  assert(vim.uv.fs_mkdir(path .. "/dir", 448))
  for _, name in ipairs({ "a", "b", "c" }) do
    fixture.write(path .. "/dir/" .. name)
  end
  t:patch_table(dot.path, "workspace", function()
    return path
  end)
  local data = await(fixture.filetree.open(path))
  local dir = await(data:resolve(path .. "/dir"))
  local a = await(data:resolve(path .. "/dir/a"))
  await(data:resolve(path .. "/dir/b"))
  local session = await(require("era.m.explorer.session").open(path, { mode = "tree" }, data))
  t:defer(function()
    session:dispose()
  end)
  -- No attached view: the remaining directory page must be requested by the action itself.
  local view = {
    winnr = vim.api.nvim_get_current_win(),
    frame = function()
      return session.state:snapshot()
    end,
    _visual_mode = function()
      return nil
    end,
  }
  local action = require("era.m.explorer.action").new({
    context = function()
      return session, view
    end,
  })
  local frame = session.state:snapshot()
  local row = assert(frame:position(dir:node()))
  await(require("ux.treeview.async").run(session.native:mark(frame, row, row, "copy", false)))
  return { path = path, session = session, view = view, action = action, directory = dir:node(), excluded = a:node() }
end

---@param selected                      table
---@return nil
local function make_pending(selected)
  await(selected.session.state:deselect_node({ selected.excluded }, true))
  local inspected = await(selected.session.state:inspect_selection())
  t.assert_true(inspected.summary.pending)
  t.assert_eq(1, inspected.subtree_roots:len())
end

t:test("read-only selection loads missing children without scanning a fully selected directory", function()
  local selected = selected_directory()
  local captured
  t:patch_table(era.fn, "select_copy_filepaths", function(options)
    captured = options.filepaths
  end)
  await(selected.action:auxiliary("copy_path"))
  t.assert_true(vim.deep_equal({ selected.path .. "/dir" }, captured))
  make_pending(selected)
  captured = nil
  await(selected.action:auxiliary("copy_path"))
  t.assert_true(vim.deep_equal({ selected.path .. "/dir/b", selected.path .. "/dir/c" }, captured))
  t.assert_false(await(selected.session.state:inspect_selection()).summary.pending)
  t.assert_false(selected.session:busy())
  t.assert_eq(2, await(selected.session.state:inspect_selection()).subtree_roots:len())
  t.assert_eq("copy", selected.session:mode())
end)

t:test("a paged directory exports every selected file once after excluding one child", function()
  local selected = selected_directory()
  for index = 4, 3000 do
    fixture.write(string.format("%s/dir/file-%04d", selected.path, index))
  end
  make_pending(selected)
  local captured
  t:patch_table(era.fn, "select_copy_filepaths", function(options)
    captured = options.filepaths
  end)
  await(selected.action:auxiliary("copy_path"))
  t.assert_eq(2999, #captured)
  local seen = {}
  for _, path in ipairs(captured) do
    t.assert_false(seen[path] == true, "duplicate source: " .. path)
    t.assert_false(path == selected.path .. "/dir/a")
    seen[path] = true
  end
  t.assert_true(seen[selected.path .. "/dir/c"] and seen[selected.path .. "/dir/file-3000"])
  t.assert_eq("copy", selected.session:mode())
  t.assert_false(selected.session:busy())
end)

t:test("cancelling source loading discards late results and preserves the selection for retry", function()
  local selected = selected_directory()
  make_pending(selected)
  local pending, resolve = stl.c.Future.new_with_resolver()
  local waiting = false
  local restore = t:patch_table(Task, "prepare_sources", function()
    waiting = true
    return pending
  end)
  local captured
  t:patch_table(era.fn, "select_copy_filepaths", function(options)
    captured = options.filepaths
  end)
  local future = selected.action:auxiliary("copy_path")
  t.wait_until(function()
    return waiting
  end, 10000)
  t.assert_true(selected.session:busy() and jobs.pending())
  t.assert_eq("loading selection · <Space> cancel", selected.session:status_text())
  local blocked = selected.action:auxiliary("copy_path")
  t.wait_until(function()
    return blocked:is_done()
  end, 10000)
  t.assert_true(blocked:is_failed())
  t:patch_table(vim.ui, "select", function(items, _, done)
    t.assert_true(vim.tbl_contains(items, "Cancel operation"))
    done("Cancel operation")
  end)
  selected.action:menu()
  resolve({ kind = "Ready" })
  await(future)
  t.assert_nil(captured)
  t.assert_false(selected.session:busy() or jobs.pending())
  t.assert_eq("copy", selected.session:mode())
  restore()
  t.wait_until(function()
    return not selected.session.data._native:is_busy()
  end, 10000)
  await(selected.action:auxiliary("copy_path"))
  t.assert_eq(2, #captured)
end)

t:test("a preparation rejection releases its lock without consuming the selection", function()
  local selected = selected_directory()
  make_pending(selected)
  t:patch_table(Task, "prepare_sources", function()
    return stl.c.Future.resolve({ kind = "Rejected", error = { code = "Io", message = "directory is unavailable" } })
  end)
  local captured
  t:patch_table(era.fn, "select_copy_filepaths", function(options)
    captured = options.filepaths
  end)
  local future = selected.action:auxiliary("copy_path")
  t.wait_until(function()
    return future:is_done()
  end, 10000)
  t.assert_true(future:is_failed())
  t.assert_true(future:get_error():find("directory is unavailable", 1, true) ~= nil)
  t.assert_nil(captured)
  t.assert_false(selected.session:busy() or jobs.pending())
  t.assert_eq("copy", selected.session:mode())
end)

t:test("real directory read failures retry after permissions recover without a separate refresh", function()
  -- chmod cannot deny reads to root or provide the same contract on Windows.
  if stl.env.IS_WIN or vim.uv.getuid() == 0 then
    return
  end
  local selected = selected_directory()
  local session, dirpath = selected.session, selected.path .. "/dir"
  make_pending(selected)
  t:defer(function()
    assert(vim.uv.fs_chmod(dirpath, 448))
  end)
  assert(vim.uv.fs_chmod(dirpath, 0))
  local captured
  t:patch_table(era.fn, "select_copy_filepaths", function(options)
    captured = options.filepaths
  end)
  for _ = 1, 2 do
    local before = session.data:source():revision()
    local future = selected.action:auxiliary("copy_path")
    t.wait_until(function()
      return future:is_done() and not session.data._native:is_busy()
    end, 10000)
    t.assert_true(future:is_failed(), "unreadable children must fail without partial output")
    t.assert_nil(captured)
    t.assert_false(session:busy() or jobs.pending())
    t.assert_eq("copy", session:mode())
    local node = session.data:source():node(selected.directory)
    t.assert_eq("error", node.load_state)
    t.assert_true(node.error.message:find("PermissionDenied", 1, true) ~= nil)
    t.assert_true(before ~= session.data:source():revision(), "the explicit action reused a cached read error")
  end

  -- A full directory remains a valid path source even with an unreadable children slot.
  await(session.state:select_node({ selected.directory }, true))
  local before = session.data:source():revision()
  await(selected.action:auxiliary("copy_path"))
  t.assert_true(vim.deep_equal({ dirpath }, captured))
  t.assert_eq(before, session.data:source():revision())
  t.assert_eq("error", session.data:source():node(selected.directory).load_state)
  make_pending(selected)
  captured = nil

  assert(vim.uv.fs_chmod(dirpath, 448))
  await(selected.action:auxiliary("copy_path"))
  t.assert_true(vim.deep_equal({ dirpath .. "/b", dirpath .. "/c" }, captured))
  t.assert_false(session:busy() or jobs.pending())
  t.assert_eq("copy", session:mode())
end)

t:test("a queued selection change cannot redirect a read-only action", function()
  local selected = selected_directory()
  make_pending(selected)
  local state = selected.session.state
  local lock = state.lock_selection
  t:patch_table(state, "lock_selection", function(self, deadline_ms, selection_revision)
    return self:clear_selection():then_(function()
      return lock(self, deadline_ms, selection_revision)
    end)
  end)
  local captured
  t:patch_table(era.fn, "select_copy_filepaths", function(options)
    captured = options.filepaths
  end)
  local future = selected.action:auxiliary("copy_path")
  t.wait_until(function()
    return future:is_done()
  end, 10000)
  t.assert_true(future:is_failed())
  t.assert_true(future:get_error():find("selection revision changed", 1, true) ~= nil)
  t.assert_nil(captured)
  t.assert_false(selected.session:busy() or jobs.pending())
  t.assert_eq(0, await(state:inspect_selection()).subtree_roots:len())
end)

t:test("closing or disposing the originating pane suppresses a delayed action", function()
  for _, dispose in ipairs({ false, true }) do
    local selected = selected_directory()
    make_pending(selected)
    local pending, resolve = stl.c.Future.new_with_resolver()
    local waiting = false
    local restore = t:patch_table(Task, "prepare_sources", function()
      waiting = true
      return pending
    end)
    local captured
    t:patch_table(era.fn, "select_copy_filepaths", function(options)
      captured = options.filepaths
    end)
    local future = selected.action:auxiliary("copy_path")
    t.wait_until(function()
      return waiting
    end, 10000)
    if dispose then
      selected.session:dispose()
    else
      selected.view._closed = true
    end
    restore()
    resolve({ kind = "Pending" })
    await(future)
    t.assert_nil(captured)
    t.assert_false(jobs.pending())
    if dispose then
      t.assert_nil(selected.session.data)
    else
      t.assert_false(selected.session:busy())
      t.assert_eq("copy", selected.session:mode())
    end
  end
end)

t:run()
