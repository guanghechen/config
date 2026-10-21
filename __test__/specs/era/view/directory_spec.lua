local t = require("__test__.support.harness").new()

local fixture = require("__test__.support.directory_picker")

t:test("the parent context row displays the parent directory metadata", function()
  if vim.uv.os_uname().sysname == "Windows_NT" then
    t.skip("needs Unix directory permissions")
  end
  local ui, directory = fixture.new(t)
  assert(vim.uv.fs_mkdir(directory .. "/parent", 493))
  assert(vim.uv.fs_chmod(directory .. "/parent", 493))
  assert(vim.uv.fs_mkdir(directory .. "/parent/current", 448))
  assert(vim.uv.fs_chmod(directory .. "/parent/current", 448))
  ui:lua([[context_path=...; surface:open(context_path)]], directory .. "/parent/current")
  ui:wait_until(function()
    return ui:lua([[
      local frame=surface:frame()
      local cache=surface.view._directory_listing
      return frame and frame:header().row_count==1 and cache and cache.entries[frame:node_at(1)]
        and surface.data:inspect(frame:source(),frame:header().root.node):path()==context_path
    ]])
  end, 5000)
  t.assert_eq(
    "drwxr-xr-x",
    ui:lua("return surface.view._directory_listing.entries[surface:frame():node_at(1)].permissions")
  )
end)

t:test("opening retries a resolve that an overlapping publication made stale", function()
  local ui, directory = fixture.new(t)
  ui:lua(
    [[
    local data, resolve = surface.data, surface.data.resolve
    stale_resolves = 0
    data.resolve = function(self, path)
      if stale_resolves < 2 then
        stale_resolves = stale_resolves + 1
        return stl.c.Future.resolve({
          kind = "Rejected",
          error = { code = "Stale", message = "resource path changed during resolve" },
        })
      end
      return resolve(self, path)
    end
    context_path = ...
    surface:open(context_path)
  ]],
    directory .. "/folder"
  )
  ui:wait_until(function()
    return ui:lua([[
      local frame = surface:frame()
      return frame and surface.data:inspect(frame:source(), frame:header().root.node):path() == context_path
    ]])
  end, 5000)
  t.assert_eq(2, ui:lua("return stale_resolves"))
  t.assert_eq(0, ui:lua("return #errors"))
end)

t:test("a focus whose entry is gone falls back to its row", function()
  local ui, directory = fixture.new(t)
  ui:lua([[surface:focus_path(..., 3)]], directory .. "/removed.lua")
  ui:wait_until(function()
    return ui:lua("return surface._focus == nil and picker.result.lnum_current:snapshot() == 3")
  end, 5000)
  t.assert_eq(0, ui:lua("return #errors"))
end)

t:test("Find Explorer uses native resources, bounded traversal and worker filtering", function()
  local ui, directory = fixture.new(t)
  t.assert_eq("userdata", ui:lua("return type(surface.state._native)"))
  t.assert_eq("  ../", ui:lua("return vim.api.nvim_buf_get_lines(picker.result:get_bufnr(),0,1,false)[1]"))
  t.assert_eq(
    directory:match("^(.*)/[^/]+$"),
    ui:lua("local resource,parent=surface:retrieve(1); assert(parent); return resource:path()")
  )
  t.assert_true(
    ui:lua([[
    local frame=surface:frame()
    local id=frame:node_at(2)
    return frame:source():node(id).completeness=="unknown"
  ]]),
    "main result must not recursively scan directories"
  )
  ui:lua([[picker.finder:set_content("alua")]])
  ui:wait_until(function()
    return ui:lua([[
      local frame=surface:frame()
      return frame:header().row_count==1 and surface:retrieve(1):info().label=="alpha.lua"
    ]])
  end, 5000)
  ui:lua([[props.flags[3].callback(); picker.finder:set_content("^ALPHA")]])
  ui:wait_until(function()
    return ui:lua("return surface:frame():header().row_count==2")
  end, 5000)
  t.assert_eq(0, ui:lua("return #errors"))
  ui:lua([[picker.finder:set_content("^folder/$")]])
  ui:wait_until(function()
    return ui:lua([[
      local frame=surface:frame()
      return frame:header().row_count==1 and frame:rows(1,1).labels[1]=="folder/"
    ]])
  end, 5000)
end)

t:test("directory previews share Filetree data and reopening retains the main buffer", function()
  local ui = fixture.new(t)
  ui:lua([[
    vim.cmd.stopinsert()
    picker.result:set_lnum_current(2)
    picker:mark_preview_dirty()
  ]])
  local started = vim.uv.hrtime()
  ui:wait_until(function()
    local ready = ui:lua([[
      return picker.preview._tree_view and picker.preview._tree_view:frame() ~= nil
    ]])
    if vim.uv.hrtime() - started > 5000000000 then
      error(vim.inspect(ui:lua([[return {
        row=picker.result.lnum_current:snapshot(), cursor=vim.api.nvim_win_get_cursor(picker.result:get_winnr()),
        focus=surface._focus, sequence=surface.state:navigation_sequence(), header=vim.inspect(surface:frame():header()),
        preview=picker.preview:get_winnr(), target=picker.preview._tree_target and picker.preview._tree_target.key,
        errors=errors,
      }]])))
    end
    return ready
  end, 5000)
  t.assert_true(ui:lua("return picker.preview._tree_state._data == surface.state._data"))
  ui:lua([[saved=picker.result:get_bufnr(); picker:hide(); picker:focus()]])
  ui:wait_until(function()
    return ui:lua("return surface.view and not surface.view:is_suspended()")
  end, 5000)
  t.assert_true(ui:lua("return saved == picker.result:get_bufnr()"))
  t.assert_eq(0, ui:lua("return #errors"))
end)

t:run()
