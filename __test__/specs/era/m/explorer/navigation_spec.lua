---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.specs.era.m.explorer.navigation" ---@type string

local fixture = require("__test__.support.explorer").new("era.m.explorer.navigation")
local t, await = fixture.t, fixture.await
local Future = require("stl.c.future")
local native_async = require("ux.treeview.async")

t:test("typed parent navigation consumes every intent before the view catches up", function()
  local path = fixture.directory()
  vim.fn.mkdir(path .. "/one/two/three", "p")
  fixture.write(path .. "/one/two/three/file")
  local widget = fixture.widget(path .. "/one/two/three")
  vim.api.nvim_feedkeys(vim.keycode("<BS><BS><BS>"), "xt", false)
  t.wait_until(function()
    return widget:get_root_filepath() == path and widget._action._navigation == nil
  end, 10000)
end)

t:test("fold input preserves parent steps queued behind a pending navigation", function()
  local path = fixture.directory()
  vim.fn.mkdir(path .. "/one/two/three", "p")
  fixture.write(path .. "/one/two/three/file")
  local widget = fixture.widget(path .. "/one/two/three")
  local session = widget:context()
  local held, release = Future.new_with_resolver()
  local navigate_parent, calls, applied = session.navigate_parent, 0, false
  t:patch_table(session, "navigate_parent", function(self)
    calls = calls + 1
    local pending = navigate_parent(self)
    if calls ~= 1 then
      return pending
    end
    return pending:then_(function(result)
      applied = true
      return held:map(function()
        return result
      end)
    end)
  end)
  local first = widget._action:root("parent")
  local second = widget._action:root("parent")
  t.wait_until(function()
    return applied
  end, 10000)
  fixture.idle(widget)
  await(widget._action:collapse())
  release(true)
  await(first)
  t.assert_eq("Applied", await(second).kind)
  fixture.idle(widget)
  t.assert_eq(2, calls)
  t.assert_eq(path .. "/one", widget:get_root_filepath())
end)

t:test("typed annotation navigation preserves repeated steps in both directions", function()
  local path = fixture.directory()
  for _, name in ipairs({ "a", "b", "c", "d" }) do
    fixture.write(path .. "/" .. name)
  end
  local widget = fixture.widget(path)
  local session, view = widget:context()
  for _, name in ipairs({ "b", "c", "d" }) do
    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(bufnr, path .. "/" .. name)
    local namespace = vim.api.nvim_create_namespace("explorer-navigation-" .. bufnr)
    t:defer(function()
      vim.diagnostic.reset(namespace)
      if vim.api.nvim_buf_is_valid(bufnr) then
        vim.api.nvim_buf_delete(bufnr, { force = true })
      end
    end)
    vim.diagnostic.set(namespace, bufnr, { { lnum = 0, col = 0, message = "error", severity = 1 } })
  end
  fixture.cursor(widget, path .. "/a")
  local query
  t.wait_until(function()
    if query and query:is_done() and not query:is_failed() and query:get_result() == 2 then
      return true
    end
    if not query or query:is_done() then
      query = session.data:next_annotation(view:frame(), 1, "error", true)
    end
    return false
  end, 10000)
  for _, case in ipairs({ { "]e]e", "c" }, { "[e[e", "d" } }) do
    vim.api.nvim_feedkeys(case[1], "xt", false)
    t.wait_until(function()
      return widget:get_cursor_filepath() == path .. "/" .. case[2] and widget._action._navigation == nil
    end, 10000)
  end
end)

t:test("new cursor input and closing a pane discard delayed annotation steps", function()
  for _, close in ipairs({ false, true }) do
    local path = fixture.directory()
    for _, name in ipairs({ "a", "b", "c", "d" }) do
      fixture.write(path .. "/" .. name)
    end
    local widget = fixture.widget(path)
    fixture.cursor(widget, path .. "/a")
    local complete, queries = nil, 0
    t:patch_table(widget._session.data, "next_annotation", function()
      queries = queries + 1
      return Future.new(function(resolve)
        complete = resolve
      end)
    end)
    local first = widget._action:annotation("error", true)
    local second = widget._action:annotation("error", true)
    t.wait_until(function()
      return complete ~= nil
    end, 10000)
    if close then
      widget:hide()
    else
      fixture.cursor(widget, path .. "/d")
    end
    complete(2)
    await(first)
    await(second)
    t.assert_eq(1, queries, "superseded queued input must not start another query")
    if not close then
      t.assert_eq(path .. "/d", widget:get_cursor_filepath())
    end
  end
end)

t:test("fixture cursor movement cannot replay over a newer reveal before publication", function()
  local path = fixture.directory()
  assert(vim.uv.fs_mkdir(path .. "/sub", 448))
  fixture.write(path .. "/sub/file")
  fixture.write(path .. "/a")
  local widget = fixture.widget(path)
  local session, view = widget:context()
  local surface = require("ux.treeview.surface")
  local request = surface.request
  local release = t:patch_table(surface, "request", function(current, ...)
    if current ~= view then
      return request(current, ...)
    end
  end)
  fixture.cursor(widget, path .. "/a")
  await(widget:reveal(path .. "/sub/file"))
  local target = await(session.data:resolve(path .. "/sub/file"))
  t.wait_until(function()
    return session.state:snapshot():header().cursor == target:node()
  end, 10000)
  vim.api.nvim_exec_autocmds("CursorMoved", { group = view._group, buf = view.bufnr, modeline = false })
  await(session.state:inspect_selection())
  t.assert_eq(target:node(), session.state:snapshot():header().cursor)
  release()
  native_async.watch(session.data._tree)
  t.wait_until(function()
    return widget:get_cursor_filepath() == path .. "/sub/file"
  end, 10000)
end)

t:test("read-only navigation reobserves a path after overlapping publications", function()
  local path = fixture.directory()
  fixture.write(path .. "/a")
  fixture.write(path .. "/b")
  local widget = fixture.widget(path)
  local session = widget._session
  local resolve = session.data.resolve
  local attempts = 0
  t:patch_table(session.data, "resolve", function(data, target)
    attempts = attempts + 1
    if attempts <= 2 then
      return Future.resolve(native_async.rejected("Stale", "overlapping publication"))
    end
    return resolve(data, target)
  end)
  local result = await(widget:reveal(path .. "/b"))
  t.assert_eq("Applied", result.kind)
  t.wait_until(function()
    return widget:get_cursor_filepath() == path .. "/b"
  end, 10000)
  t.assert_eq(3, attempts)
end)

t:test("superseded or disposed navigation cannot retry a delayed stale observation", function()
  for _, dispose in ipairs({ false, true }) do
    local path = fixture.directory()
    fixture.write(path .. "/a")
    fixture.write(path .. "/b")
    local widget = fixture.widget(path)
    local session = widget._session
    local resolve = session.data.resolve
    local deliver, attempts = nil, 0
    t:patch_table(session.data, "resolve", function(data, target)
      if target == path .. "/a" then
        attempts = attempts + 1
        return Future.new(function(complete)
          deliver = complete
        end)
      end
      return resolve(data, target)
    end)
    local earlier = widget:reveal(path .. "/a")
    t.wait_until(function()
      return deliver ~= nil
    end, 10000)
    if dispose then
      widget:dispose()
    else
      await(widget:reveal(path .. "/b"))
    end
    deliver(native_async.rejected("Stale", "late observation"))
    t.assert_eq("NoChange", await(earlier).kind)
    t.assert_eq(1, attempts)
    if not dispose then
      t.wait_until(function()
        return widget:get_cursor_filepath() == path .. "/b"
      end, 10000)
    end
  end
end)

t:test("navigation bounds stale retries and preserves other resolve failures", function()
  for _, case in ipairs({ { "Stale", 3 }, { "NotFound", 1 }, { "ProviderError", 1 } }) do
    local path = fixture.directory()
    fixture.write(path .. "/a")
    local widget = fixture.widget(path)
    local session = widget._session
    local attempts = 0
    t:patch_table(session.data, "resolve", function()
      attempts = attempts + 1
      return Future.resolve(native_async.rejected(case[1], "path unavailable"))
    end)
    local future = session:navigate_path(path .. "/a", false)
    t.wait_until(function()
      return future:is_done()
    end, 10000)
    t.assert_true(future:is_failed())
    t.assert_true(tostring(future:get_error()):find(case[1] .. ": path unavailable", 1, true) ~= nil)
    t.assert_eq(case[2], attempts)
    t.assert_eq(path, widget:get_root_filepath())
  end
end)

t:run()
