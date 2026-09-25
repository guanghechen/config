---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.specs.era.m.explorer.inputs" ---@type string

local fixture = require("__test__.support.explorer").new("era.m.explorer.inputs")
local t, await = fixture.t, fixture.await

---@param path                          string
---@return integer, integer
local function diagnostic(path)
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(bufnr, path)
  local namespace = vim.api.nvim_create_namespace("explorer-input-" .. bufnr)
  t:defer(function()
    vim.diagnostic.reset(namespace)
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end)
  return bufnr, namespace
end

---@param widget                        era.m.explorer.Widget
---@param count                         integer
---@return nil
local function displayed(widget, count)
  local _, view = widget:context()
  t.wait_until(function()
    return view._filetree_annotations and view._filetree_annotations.rows[1].diagnostics[1] == count
  end, 10000)
end

t:test("reopening a retained data source withdraws diagnostics cleared while unsubscribed", function()
  local path = fixture.directory()
  fixture.write(path .. "/a")
  local bufnr, namespace = diagnostic(path .. "/a")
  local first = fixture.widget(path)
  vim.diagnostic.set(namespace, bufnr, { { lnum = 0, col = 0, message = "error", severity = 1 } })
  displayed(first, 1)
  local data = first._session.data
  first:dispose()
  vim.diagnostic.reset(namespace, bufnr)
  local second = fixture.widget(path, { data = data })
  displayed(second, 0)
end)

t:test("Busy diagnostic and Git inputs are retried without another editor event", function()
  local path = fixture.directory()
  fixture.write(path .. "/a")
  local bufnr, namespace = diagnostic(path .. "/a")
  local widget = fixture.widget(path)
  local session = widget._session
  t.wait_until(function()
    return not session._subscriptions._running
  end, 10000)
  local data = session.data
  local diagnostics, git = data.sync_diagnostics, data.set_git
  local calls = { diagnostic = 0, git = 0 }
  t:patch_table(data, "sync_diagnostics", function(self, ...)
    calls.diagnostic = calls.diagnostic + 1
    if calls.diagnostic == 1 then
      return stl.c.Future.resolve({ kind = "Rejected", error = { code = "Busy", message = "IO queue is full" } })
    end
    return diagnostics(self, ...)
  end)
  t:patch_table(data, "set_git", function(self, ...)
    calls.git = calls.git + 1
    if calls.git == 1 then
      return stl.c.Future.resolve({ kind = "Rejected", error = { code = "Busy", message = "IO queue is full" } })
    end
    return git(self, ...)
  end)
  vim.diagnostic.set(namespace, bufnr, { { lnum = 0, col = 0, message = "error", severity = 1 } })
  await(session:refresh())
  displayed(widget, 1)
  t.assert_true(calls.diagnostic >= 2)
  t.assert_true(calls.git >= 2)
end)

t:test("disposing during ignore preload cannot publish a late Git input", function()
  local path = fixture.directory()
  fixture.write(path .. "/a")
  local widget = fixture.widget(path)
  local session = widget._session
  local controller, data = session._subscriptions, session.data
  t.wait_until(function()
    return not controller._running and not data._native:is_busy()
  end, 10000)
  t:patch_table(dot.path, "is_git_repo", function()
    return true
  end)
  t:patch_table(require("era.m.git.state"), "refresh", function()
    return stl.c.Future.resolve(nil)
  end)
  local pending
  local ignore = require("era.m.git.ignore")
  t:patch_table(ignore, "preload", function()
    return stl.c.Future.new(function(resolve)
      pending = resolve
    end)
  end)
  local writes, set_git = 0, data.set_git
  t:patch_table(data, "set_git", function(self, ...)
    writes = writes + 1
    return set_git(self, ...)
  end)
  ignore.clear()
  t.wait_until(function()
    return pending ~= nil
  end, 10000)
  widget:dispose()
  pending(nil)
  t.wait_until(function()
    return not controller._running
  end, 10000)
  t.assert_eq(0, writes)
end)

t:test("filesystem publications refresh Git without selection or annotation feedback", function()
  local Git = require("era.m.git.state")
  local refreshes = 0
  t:patch_table(Git, "refresh", function(force)
    t.assert_false(force)
    refreshes = refreshes + 1
    Git.o_refreshed:next({ change_scope = "unknown", generation = refreshes })
    return stl.c.Future.resolve(nil)
  end)
  local path = fixture.directory()
  fixture.write(path .. "/a")
  local widget = fixture.widget(path)
  local session, view = widget:context()
  t.wait_until(function()
    return session.watch and session.watch.directories > 0
  end, 10000)
  local before = refreshes
  fixture.write(path .. "/external")
  t.wait_until(function()
    return view:frame():header().row_count == 2 and refreshes > before
  end, 10000)

  before = refreshes
  await(session:operate(view, "create", { path = "created" }))
  fixture.idle(widget)
  t.assert_true(refreshes > before, "completed IO must refresh Git")

  -- The cursor helper resolves its path; keep that filesystem work outside the state-only phase.
  fixture.cursor(widget, path .. "/a")
  -- Wait through native watch coalescing before testing state-only input.
  local observed, quiet_since = refreshes, vim.uv.hrtime()
  t.wait_until(function()
    if refreshes ~= observed or session.data._native:is_busy() or session._subscriptions._running then
      observed, quiet_since = refreshes, vim.uv.hrtime()
    end
    return vim.uv.hrtime() - quiet_since > 250000000
  end, 10000, "Git annotations must not feed back into filesystem refresh")
  local revision = session.data:source():revision()
  before = refreshes
  await(widget._action:mark("copy"))
  local bufnr, namespace = diagnostic(path .. "/a")
  vim.diagnostic.set(namespace, bufnr, { { lnum = 0, col = 0, message = "error", severity = 1 } })
  displayed(widget, 1)
  t.wait_until(function()
    return session:mode(view:frame()) == "copy" and not session._subscriptions._running
  end, 10000)
  t.assert_eq(revision, session.data:source():revision())
  t.assert_false(
    vim.wait(250, function()
      return refreshes ~= before
    end, 10),
    "selection and diagnostics must not request another Git refresh"
  )
end)

t:test("partial IO refreshes Git after the last pane and subscription are disposed", function()
  local path = fixture.directory()
  assert(vim.uv.fs_mkdir(path .. "/dest", 448))
  fixture.write(path .. "/a")
  fixture.write(path .. "/b")
  fixture.write(path .. "/dest/b")
  local widget = fixture.widget(path)
  fixture.cursor(widget, path .. "/a")
  vim.cmd.normal({ args = { "Vj" }, bang = true })
  await(widget._action:mark("copy"))
  fixture.cursor(widget, path .. "/dest")
  local confirmation
  t:patch_table(vim.ui, "select", function(_, _, done)
    confirmation = done
  end)
  local job = await(widget._action:operate("paste"))
  local session = widget._session
  t:defer(function()
    if session.job then
      job:cancel()
      t.wait_until(function()
        return session.job == nil
      end, 10000)
    end
  end)
  t.wait_until(function()
    return confirmation ~= nil and session._counts.success == 1
  end, 10000)
  widget:dispose()
  t.assert_eq(nil, session._subscriptions)
  local refreshes = 0
  t:patch_table(require("era.m.git.state"), "refresh", function(force)
    t.assert_false(force)
    refreshes = refreshes + 1
    return stl.c.Future.resolve(nil)
  end)
  confirmation("Skip", 1)
  t.wait_until(function()
    return session.job == nil
  end, 10000)
  t.assert_true(job:status().terminal)
  t.assert_eq(1, session._counts.success)
  t.assert_eq(1, session._counts.skipped)
  t.assert_eq(1, refreshes)
  t.assert_true(vim.uv.fs_stat(path .. "/dest/a") ~= nil)
end)

t:test("ignore preloading keeps byte paths and isolates a broken viewport resource", function()
  local path = fixture.directory()
  for _, name in ipairs({ "a", "b", "c", "d" }) do
    fixture.write(path .. "/" .. name)
  end
  local widget = fixture.widget(path)
  local session, view = widget:context()
  local data, inspect = session.data, session.data.inspect
  local raw = path .. "/invalid-" .. string.char(255)
  local captured
  t:patch_table(require("era.m.git.ignore"), "preload", function(paths)
    captured = paths
    return stl.c.Future.resolve(nil)
  end)
  t:patch_table(data, "inspect", function(self, source, node)
    local resource = inspect(self, source, node)
    local name = resource:path():sub(-1)
    if name == "c" then
      error("unavailable viewport resource")
    end
    return {
      path = function()
        return name == "a" and raw or name == "d" and path .. "-sibling/file" or resource:path()
      end,
    }
  end)
  session._subscriptions:visible(view:frame(), 1, 4)
  t.assert_eq(2, #captured)
  t.assert_eq(raw, captured[1])
  t.assert_eq(path .. "/b", captured[2])
  t.assert_true(fixture.messages[#fixture.messages]:find("unavailable viewport resource", 1, true) ~= nil)
end)

t:run()
