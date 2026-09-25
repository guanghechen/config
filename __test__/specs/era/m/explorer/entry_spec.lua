---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.specs.era.m.explorer.entry" ---@type string

local fixture = require("__test__.support.explorer").new("era.m.explorer.entry")
local t, await = fixture.t, fixture.await

t:test("the default Explorer entry opens native panes and retains state across hide and focus", function()
  local path = fixture.directory()
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
  t.wait_until(function()
    local view = widget._views[vim.api.nvim_get_current_tabpage()]
    return view and view:frame() and view:frame():header().row_count == 1
  end, 10000)
  local session, view = widget:context()
  t.assert_eq("userdata", type(session.native))
  local id = view:frame():header().state_id
  entry.hide()
  t.assert_false(widget:isvisible())
  entry.reveal(path .. "/file")
  t.wait_until(function()
    local current = widget._views[vim.api.nvim_get_current_tabpage()]
    return current and current:frame() and current:frame():header().row_count == 1
  end, 10000)
  t.assert_eq(id, widget:context().state:snapshot():header().state_id)
end)

t:test("reveal chooses the most specific child alias and preserves an alias workspace root", function()
  if stl.env.IS_WIN then
    return
  end
  local base = fixture.directory()
  local workspace = base .. "/workspace"
  assert(vim.uv.fs_mkdir(workspace, 448))
  assert(vim.uv.fs_mkdir(base .. "/target", 448))
  assert(vim.uv.fs_mkdir(base .. "/target/nested", 448))
  fixture.write(base .. "/target/nested/file")
  assert(vim.uv.fs_symlink("../target", workspace .. "/broad"))
  assert(vim.uv.fs_symlink("../target/nested", workspace .. "/specific"))
  local widget = fixture.widget(workspace)
  await(widget:reveal(base .. "/target/nested/file"))
  local session, view = widget:context()
  t.wait_until(function()
    return widget:get_cursor_filepath() == workspace .. "/specific/file"
  end, 10000)
  t.assert_eq(workspace, session:root(view:frame()):path())
  assert(vim.uv.fs_symlink("target", base .. "/alias"))
  local aliased = fixture.widget(base .. "/alias")
  await(aliased:reveal(base .. "/target/nested/file"))
  t.wait_until(function()
    return aliased:get_cursor_filepath() == base .. "/alias/nested/file"
  end, 10000)
  t.assert_eq(base .. "/alias", aliased:get_root_filepath())
end)

t:run()
