---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.specs.era.m.explorer.navigation" ---@type string

local fixture = require("__test__.support.explorer").new("era.m.explorer.navigation")
local t, await = fixture.t, fixture.await
local Future = require("stl.c.future")
local native_async = require("ux.treeview.async")

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
