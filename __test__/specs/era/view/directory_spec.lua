---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.specs.era.view.directory" ---@type string

local t = require("__test__.support.harness").new("era.view.directory")

local fixture = require("__test__.support.directory_picker")

t:test("the parent context row displays the parent directory metadata", function()
  if vim.uv.os_uname().sysname == "Windows_NT" then
    return
  end
  local ui, directory = fixture.new(t)
  assert(vim.uv.fs_mkdir(directory .. "/parent", 493))
  assert(vim.uv.fs_chmod(directory .. "/parent", 493))
  assert(vim.uv.fs_mkdir(directory .. "/parent/current", 448))
  assert(vim.uv.fs_chmod(directory .. "/parent/current", 448))
  ui:rpc("nvim_exec_lua", [[context_path=...; surface:open(context_path)]], { directory .. "/parent/current" })
  t.wait_until(function()
    return ui:rpc(
      "nvim_exec_lua",
      [[
      local frame=surface:frame()
      local cache=surface.view._directory_listing
      return frame and frame:header().row_count==1 and cache and cache.entries[frame:node_at(1)]
        and surface.data:inspect(frame:source(),frame:header().root.node):path()==context_path
    ]],
      {}
    )
  end, 5000)
  t.assert_eq(
    "drwxr-xr-x",
    ui:rpc(
      "nvim_exec_lua",
      "return surface.view._directory_listing.entries[surface:frame():node_at(1)].permissions",
      {}
    )
  )
end)

t:test("Find Explorer uses native resources, bounded traversal and worker filtering", function()
  local ui, directory = fixture.new(t)
  t.assert_eq("userdata", ui:rpc("nvim_exec_lua", "return type(surface.state._native)", {}))
  t.assert_eq(
    "  ../",
    ui:rpc("nvim_exec_lua", "return vim.api.nvim_buf_get_lines(picker.result:get_bufnr(),0,1,false)[1]", {})
  )
  t.assert_eq(
    directory:match("^(.*)/[^/]+$"),
    ui:rpc("nvim_exec_lua", "local resource,parent=surface:retrieve(1); assert(parent); return resource:path()", {})
  )
  t.assert_true(
    ui:rpc(
      "nvim_exec_lua",
      [[
    local frame=surface:frame()
    local id=frame:node_at(2)
    return frame:source():node(id).completeness=="unknown"
  ]],
      {}
    ),
    "main result must not recursively scan directories"
  )
  ui:rpc("nvim_exec_lua", [[picker.finder:set_content("alua")]], {})
  t.wait_until(function()
    return ui:rpc(
      "nvim_exec_lua",
      [[
      local frame=surface:frame()
      return frame:header().row_count==1 and surface:retrieve(1):info().label=="alpha.lua"
    ]],
      {}
    )
  end, 5000)
  ui:rpc("nvim_exec_lua", [[props.flags[3].callback(); picker.finder:set_content("^ALPHA")]], {})
  t.wait_until(function()
    return ui:rpc("nvim_exec_lua", "return surface:frame():header().row_count==2", {})
  end, 5000)
  t.assert_eq(0, ui:rpc("nvim_exec_lua", "return #errors", {}))
  ui:rpc("nvim_exec_lua", [[picker.finder:set_content("^folder/$")]], {})
  t.wait_until(function()
    return ui:rpc(
      "nvim_exec_lua",
      [[
      local frame=surface:frame()
      return frame:header().row_count==1 and frame:rows(1,1).labels[1]=="folder/"
    ]],
      {}
    )
  end, 5000)
end)

t:test("directory previews share Filetree data and reopening retains the main buffer", function()
  local ui = fixture.new(t)
  ui:rpc(
    "nvim_exec_lua",
    [[
    vim.cmd.stopinsert()
    picker.result:set_lnum_current(2)
    picker:mark_preview_dirty()
  ]],
    {}
  )
  local started = vim.uv.hrtime()
  t.wait_until(function()
    local ready = ui:rpc(
      "nvim_exec_lua",
      [[
      return picker.preview._tree_view and picker.preview._tree_view:frame() ~= nil
    ]],
      {}
    )
    if vim.uv.hrtime() - started > 5000000000 then
      error(vim.inspect(ui:rpc(
        "nvim_exec_lua",
        [[return {
        row=picker.result.lnum_current:snapshot(), cursor=vim.api.nvim_win_get_cursor(picker.result:get_winnr()),
        focus=surface._focus, sequence=surface.state:navigation_sequence(), header=vim.inspect(surface:frame():header()),
        preview=picker.preview:get_winnr(), target=picker.preview._tree_target and picker.preview._tree_target.key,
        errors=errors,
      }]],
        {}
      )))
    end
    return ready
  end, 5000)
  t.assert_true(ui:rpc("nvim_exec_lua", "return picker.preview._tree_state._data == surface.state._data", {}))
  ui:rpc("nvim_exec_lua", [[saved=picker.result:get_bufnr(); picker:hide(); picker:focus()]], {})
  t.wait_until(function()
    return ui:rpc("nvim_exec_lua", "return surface.view and not surface.view:is_suspended()", {})
  end, 5000)
  t.assert_true(ui:rpc("nvim_exec_lua", "return saved == picker.result:get_bufnr()", {}))
  t.assert_eq(0, ui:rpc("nvim_exec_lua", "return #errors", {}))
end)

t:run()
