local t = require("__test__.support.harness").new()
local fixture = require("__test__.support.explorer").new(t)
local await, root_is = fixture.await, fixture.root_is

t:test("the default Explorer entry opens native panes and retains state across hide and focus", function()
  local path = t:tempdir()
  fixture.write(path .. "/file")
  t:patch_table(dot.path, "workspace", function()
    return path
  end)
  local entry = require("era.widget.explorer")
  local widget = entry.get_widget()
  t:defer(function()
    widget:dispose()
    entry.widget = nil
  end)
  entry.focus()
  await(widget._ready)
  fixture.shown(widget, 1)
  local session, view = widget:context()
  t.assert_eq("userdata", type(session.native))
  local id = view:frame():header().state_id
  entry.hide()
  t.assert_false(widget:isvisible())
  entry.reveal(path .. "/file")
  fixture.shown(widget, 1)
  t.assert_eq(id, widget:context().state:snapshot():header().state_id)
end)

t:test("cold focus_cwd keeps the constructor workspace as the gw destination", function()
  local path = t:tempdir()
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
  t.assert_eq(path, widget:context().native:workspace_path())
  fixture.await(widget:action():root("workspace"))
  root_is(widget, path)
end)

t:test("default reveal and Copy Path preserve a Unix backslash name", function()
  if stl.env.IS_WIN then
    t.skip("a backslash is a path separator on Windows")
  end
  local base = t:tempdir()
  local source = base .. "/a\\b.txt"
  fixture.write(source)
  local widget = fixture.widget(base)
  local entry = require("era.widget.explorer")
  t:patch_table(entry, "widget", widget)
  t:patch_table(dot.path, "cwd", function()
    return base
  end)
  entry.reveal(source)
  t.wait_until(function()
    return widget:get_cursor_filepath() == source
  end, 10000)
  local copied
  t:patch_table(stl.nvim.fn, "copy", function(value)
    copied = value
  end)
  for _, pair in ipairs({ { "1", source }, { "2", [[a\b.txt]] }, { "3", [[a\b.txt]] } }) do
    t:patch_table(era.m.select, "open", function(options)
      options.on_choice({ key = pair[1] })
      return 0
    end)
    await(widget:action():auxiliary("copy_path"))
    t.assert_eq(pair[2], copied)
  end
end)

t:run()
