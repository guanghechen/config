---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.specs.era.m.explorer.opening" ---@type string

local fixture = require("__test__.support.explorer").new("era.m.explorer.opening")
local Widget = require("era.m.explorer.widget")
local Session = require("era.m.explorer.session")
local t = fixture.t

---@param widget                        era.m.explorer.Widget
---@param path                          string
---@return nil
local function root_is(widget, path)
  t.wait_until(function()
    return widget._session and widget:get_root_filepath() == path and next(widget._views) ~= nil
  end, 10000)
  fixture.idle(widget)
end

t:test("cold focus_cwd keeps the constructor workspace as the gw destination", function()
  local path = fixture.directory()
  assert(vim.uv.fs_mkdir(path .. "/sub", 448))
  fixture.write(path .. "/sub/file")
  t:patch_table(dot.path, "workspace", function()
    return path
  end)
  t:patch_table(dot.path, "cwd", function()
    return path .. "/sub"
  end)
  local entry = require("era.widget.explorer")
  t:defer(function()
    if entry.widget then
      entry.widget:dispose()
      entry.widget = nil
    end
  end)
  entry.focus_cwd()
  local widget = entry.get_widget()
  root_is(widget, path .. "/sub")
  t.assert_eq(path, widget._session.native:workspace_path())
  fixture.await(widget._action:root("workspace"))
  root_is(widget, path)
end)

t:test("a missing constructor workspace does not block another root and can be recreated", function()
  local path = fixture.directory()
  local workspace, target = path .. "/missing", path .. "/target"
  assert(vim.uv.fs_mkdir(target, 448))
  fixture.write(target .. "/file")
  local widget = Widget.new({ name = "missing-workspace", root = workspace })
  t:defer(function()
    widget:dispose()
  end)
  fixture.await(widget:set_root(target))
  root_is(widget, target)
  t.assert_eq(workspace, widget._session.native:workspace_path())
  t.assert_nil(widget._session.native:workspace())
  t.assert_eq(nil, widget._open_error)
  assert(vim.uv.fs_mkdir(workspace, 448))
  fixture.write(workspace .. "/restored")
  fixture.await(widget._action:root("workspace"))
  root_is(widget, workspace)
end)

t:test("an observed workspace keeps its resolved path after obsolete parent components disappear", function()
  for _, replace in ipairs({ false, true }) do
    local path = fixture.directory()
    for _, name in ipairs({ "unused", "workspace", "other" }) do
      assert(vim.uv.fs_mkdir(path .. "/" .. name, 448))
    end
    fixture.write(path .. "/workspace/file")
    fixture.write(path .. "/other/file")
    local input = path .. "/unused/../workspace"
    local widget = Widget.new({ name = "resolved-workspace-" .. tostring(replace), root = input })
    t:defer(function()
      widget:dispose()
    end)
    if replace then
      fixture.await(widget:set_root(input .. "/"))
    else
      widget:focus()
      fixture.await(widget._ready)
    end
    local workspace = widget._session:root():path()
    root_is(widget, workspace)
    t.assert_true(widget._session.native:workspace() ~= nil)
    t.assert_eq(workspace, widget._session.native:workspace_path())
    fixture.await(widget:set_root(path .. "/other"))
    root_is(widget, path .. "/other")
    assert(vim.uv.fs_rmdir(path .. "/unused"))
    fixture.await(widget._action:root("workspace"))
    root_is(widget, workspace)
  end
end)

t:test("cold child replacement retains a workspace observed through filesystem parent resolution", function()
  for _, linked in ipairs({ false, true }) do
    if linked and stl.env.IS_WIN then
      break
    end
    local path = assert(vim.uv.fs_realpath(fixture.directory()))
    local prefix = path
    if linked then
      assert(vim.uv.fs_mkdir(path .. "/outside", 448))
      assert(vim.uv.fs_mkdir(path .. "/outside/leaf", 448))
      assert(vim.uv.fs_symlink("outside/leaf", path .. "/unused"))
      prefix = path .. "/outside"
    else
      assert(vim.uv.fs_mkdir(path .. "/unused", 448))
    end
    assert(vim.uv.fs_mkdir(prefix .. "/workspace", 448))
    assert(vim.uv.fs_mkdir(prefix .. "/workspace/sub", 448))
    fixture.write(prefix .. "/workspace/sub/file")
    local input = path .. "/unused/../workspace"
    local widget = Widget.new({ name = "child-workspace-" .. tostring(linked), root = input })
    t:defer(function()
      widget:dispose()
    end)
    fixture.await(widget:set_root(input .. "/sub"))
    root_is(widget, prefix .. "/workspace/sub")
    t.assert_true(widget._session.native:workspace() ~= nil)
    t.assert_eq(prefix .. "/workspace", widget._session.native:workspace_path())
    if linked then
      assert(vim.uv.fs_unlink(path .. "/unused"))
    else
      assert(vim.uv.fs_rmdir(path .. "/unused"))
    end
    fixture.await(widget._action:root("workspace"))
    root_is(widget, prefix .. "/workspace")
  end
end)

t:test("parent traversal after a child symlink cannot rebind workspace to an external ancestor", function()
  if stl.env.IS_WIN then
    return
  end
  local path = assert(vim.uv.fs_realpath(fixture.directory()))
  for _, name in ipairs({ "workspace", "outside", "outside/leaf", "outside/other" }) do
    assert(vim.uv.fs_mkdir(path .. "/" .. name, 448))
  end
  fixture.write(path .. "/workspace/file")
  fixture.write(path .. "/outside/other/file")
  assert(vim.uv.fs_symlink("../outside/leaf", path .. "/workspace/link"))
  local widget = Widget.new({ name = "external-parent-workspace", root = path .. "/workspace" })
  t:defer(function()
    widget:dispose()
  end)
  fixture.await(widget:set_root(path .. "/workspace/link/../other"))
  root_is(widget, path .. "/outside/other")
  t.assert_eq(path .. "/workspace", widget._session.native:workspace_path())
  fixture.await(widget._action:root("workspace"))
  root_is(widget, path .. "/workspace")
end)

t:test("replacement roots discard queued navigation and late opening completion", function()
  for _, success in ipairs({ false, true }) do
    local path = fixture.directory()
    for _, name in ipairs({ "one", "two" }) do
      assert(vim.uv.fs_mkdir(path .. "/" .. name, 448))
      fixture.write(path .. "/" .. name .. "/file")
    end
    local resolve, reject
    local pending = stl.c.Future.new(function(done, fail)
      resolve, reject = done, fail
    end)
    local open, first = Session.open, true
    local restore = t:patch_table(Session, "open", function(...)
      if first then
        first = false
        return pending
      end
      return open(...)
    end)
    local widget = Widget.new({ name = "replaced-opening-" .. tostring(success), root = path })
    t:defer(function()
      widget:dispose()
    end)
    local reveal = widget:reveal(path .. "/one/file")
    widget:set_root(path .. "/one")
    fixture.await(widget:set_root(path .. "/two"))
    root_is(widget, path .. "/two")
    local session = widget._session
    local navigation_calls = 0
    if success then
      local obsolete = fixture.await(open(path, widget:get_display(), nil, path))
      t:patch_table(obsolete, "navigate_path", function()
        navigation_calls = navigation_calls + 1
        return stl.c.Future.resolve({ kind = "NoChange" })
      end)
      resolve(obsolete)
      t.wait_until(function()
        return obsolete._disposed
      end, 10000)
    else
      reject("ProviderError: obsolete opening")
    end
    fixture.await(reveal)
    t.assert_eq(0, navigation_calls, "obsolete opening must not receive queued navigation")
    t.assert_eq(session, widget._session)
    t.assert_eq(path, session.native:workspace_path())
    t.assert_eq(nil, widget._open_error)
    root_is(widget, path .. "/two")
    restore()
  end
end)

t:test("a shared-data workspace renamed after resolution retains its observed occurrence", function()
  local path = fixture.directory()
  assert(vim.uv.fs_mkdir(path .. "/child", 448))
  fixture.write(path .. "/child/file")
  local owner = fixture.widget(path)
  fixture.cursor(owner, path .. "/child")
  local data = owner._session.data
  local create_state, moved = data.create_state, false
  t:patch_table(data, "create_state", function(self, root, display)
    if not moved then
      moved = true
      fixture.await(owner._action:operate({ kind = "rename", name = "renamed" }))
      fixture.idle(owner)
      t.assert_true(vim.uv.fs_stat(path .. "/renamed") ~= nil)
    end
    return create_state(self, root, display)
  end)
  local widget = Widget.new({ name = "concurrent-workspace", root = path .. "/child", data = data })
  t:defer(function()
    widget:dispose()
  end)
  widget:focus()
  fixture.await(widget._ready)
  root_is(widget, path .. "/renamed")
  t.assert_true(widget._session.native:workspace() ~= nil)
  t.assert_eq(path .. "/renamed", widget._session.native:workspace_path())
  fixture.await(widget:set_root(path))
  root_is(widget, path)
  fixture.await(widget._action:root("workspace"))
  root_is(widget, path .. "/renamed")
end)

t:test("custom roots and shared data fix their own workspace while a shared session retains its owner", function()
  local path = fixture.directory()
  for _, name in ipairs({ "custom", "independent", "destination" }) do
    assert(vim.uv.fs_mkdir(path .. "/" .. name, 448))
    fixture.write(path .. "/" .. name .. "/file")
  end
  local owner = fixture.widget(path .. "/custom")
  local shared = Widget.new({ name = "shared-workspace", root = path, session = owner._session })
  t:defer(function()
    shared:dispose()
  end)
  fixture.await(shared:set_root(path .. "/destination"))
  root_is(shared, path .. "/destination")
  t.assert_eq(owner._session, shared._session)
  t.assert_eq(path .. "/custom", shared._session.native:workspace_path())

  local independent = Widget.new({
    name = "independent-workspace",
    root = path .. "/independent",
    data = owner._session.data,
  })
  t:defer(function()
    independent:dispose()
  end)
  fixture.await(independent:set_root(path .. "/destination"))
  root_is(independent, path .. "/destination")
  t.assert_eq(path .. "/independent", independent._session.native:workspace_path())
  t.assert_eq(path .. "/custom", owner._session.native:workspace_path())
  fixture.await(independent._action:root("workspace"))
  root_is(independent, path .. "/independent")
end)

t:test("one failed opening reports once across views, display changes and reveal; each retry reports once", function()
  local reports = {}
  t:patch_table(stl.reporter, "warn", function(value)
    reports[#reports + 1] = value.message
  end)
  local path = fixture.directory() .. "/missing"
  local widget = Widget.new({ name = "opening-reports", root = path })
  t:defer(function()
    widget:dispose()
  end)
  widget:focus()
  widget:toggle_flag(4)
  widget:reveal(path .. "/file")
  vim.cmd.tabnew()
  local tabnr = vim.api.nvim_get_current_tabpage()
  t:defer(function()
    if vim.api.nvim_tabpage_is_valid(tabnr) then
      vim.api.nvim_set_current_tabpage(tabnr)
      vim.cmd("tabclose!")
    end
  end)
  widget:focus()
  t.wait_until(function()
    return widget._ready:is_failed() and not widget._display_scheduled
  end, 10000)
  t.assert_eq(1, #reports)
  t.assert_true(reports[1]:find("NotFound", 1, true) ~= nil)
  t.assert_true(reports[1]:find("R in Explorer", 1, true) ~= nil)
  t.assert_true(reports[1]:find("stack traceback", 1, true) == nil)
  t.assert_true(
    widget._ready:get_error():find("stack traceback", 1, true) ~= nil,
    "the Future retains diagnostic detail"
  )

  local previous = widget._ready
  vim.api.nvim_feedkeys("R", "xt", false)
  t.wait_until(function()
    return widget._ready ~= previous and widget._ready:is_failed()
  end, 10000)
  t.assert_eq(2, #reports)
  assert(vim.uv.fs_mkdir(path, 448))
  fixture.write(path .. "/file")
  fixture.await(widget:refresh())
  t.wait_until(function()
    local view = widget._views[tabnr]
    return view and view:frame() and view:frame():header().row_count == 1
  end, 10000)
  t.assert_eq(2, #reports)
  t.assert_eq(nil, widget._open_error)
end)

t:test("late opening failures cannot report or reclaim a newer opening or disposed widget", function()
  for _, dispose in ipairs({ false, true }) do
    local reports = {}
    t:patch_table(stl.reporter, "warn", function(value)
      reports[#reports + 1] = value.message
    end)
    local reject
    local pending = stl.c.Future.new(function(_, fail)
      reject = fail
    end)
    local open = Session.open
    local first = true
    local restore = t:patch_table(Session, "open", function(...)
      if first then
        first = false
        return pending
      end
      return open(...)
    end)
    local path = fixture.directory()
    fixture.write(path .. "/file")
    local widget = Widget.new({ name = "obsolete-opening-" .. tostring(dispose), root = path })
    t:defer(function()
      widget:dispose()
    end)
    widget:focus()
    if dispose then
      widget:dispose()
    else
      fixture.await(widget:set_root(path))
      t.wait_until(function()
        local view = widget._views[vim.api.nvim_get_current_tabpage()]
        return view and view:frame()
      end, 10000)
    end
    reject("ProviderError: obsolete opening")
    t.assert_eq(0, #reports)
    t.assert_eq(nil, widget._open_error)
    if not dispose then
      t.assert_true(widget:context() ~= nil)
    end
    restore()
  end
end)

t:test("a view attachment failure after a successful opening still reports", function()
  local reports = {}
  t:patch_table(stl.reporter, "warn", function(value)
    reports[#reports + 1] = value.message
  end)
  local path = fixture.directory()
  fixture.write(path .. "/file")
  local widget = Widget.new({ name = "attachment-error", root = path })
  t:defer(function()
    widget:dispose()
  end)
  fixture.await(widget._ready)
  t:patch_table(require("ux.filetree"), "attach", function()
    error("attachment failed", 0)
  end)
  widget:focus()
  t.assert_eq(1, #reports)
  t.assert_true(reports[1]:find("attachment failed", 1, true) ~= nil)
  t.assert_eq(nil, widget._open_error)
end)

t:run()
