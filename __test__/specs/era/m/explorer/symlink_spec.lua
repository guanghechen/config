---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.specs.era.m.explorer.symlink" ---@type string

local support = require("__test__.support.explorer").new("era.m.explorer.symlink")
local t, await = support.t, support.await

---@return string
local function directory()
  local root = support.directory()
  vim.fn.mkdir(root .. "/target/nested", "p")
  vim.fn.mkdir(root .. "/container", "p")
  support.write(root .. "/target/nested/file.lua")
  support.write(root .. "/plain.lua")
  assert(vim.uv.fs_symlink("target", root .. "/dir-link", { dir = true }))
  assert(vim.uv.fs_symlink("plain.lua", root .. "/file-link.lua"))
  assert(vim.uv.fs_symlink("missing", root .. "/broken-link", { dir = true }))
  assert(vim.uv.fs_symlink("../target", root .. "/container/alias", { dir = true }))
  return root
end

t:test("native resources keep link identity separate from directory interaction", function()
  local root = directory()
  local widget = support.widget(root)
  local session = widget:context()
  for _, case in ipairs({
    { "dir-link", "link", true },
    { "file-link.lua", "link", false },
    { "broken-link", "link", false },
    { "target", "directory", true },
    { "plain.lua", "file", false },
    { "dir-link/nested/file.lua", "file", false },
  }) do
    local info = await(session.data:resolve(root .. "/" .. case[1])):info()
    t.assert_eq(case[2], info.kind, case[1] .. " entry identity")
    t.assert_eq(case[3], info.directory, case[1] .. " interaction type")
  end
end)

t:test("directory compression does not cross a link or hide its entry", function()
  local root = directory()
  local widget = support.widget(root)
  local session, view = widget:context()
  local resources = {}
  for _, path in ipairs({
    "dir-link",
    "dir-link/nested",
    "container",
    "container/alias",
    "container/alias/nested",
    "target/nested",
  }) do
    resources[path] = await(session.data:resolve(root .. "/" .. path))
  end
  await(session.state:set_expanded({ session.data.root }, true, true))
  t.wait_until(function()
    local frame = view:frame()
    for _, resource in pairs(resources) do
      if not frame:position(resource:node()) then
        return false
      end
    end
    return true
  end, 10000)
  local frame = view:frame()
  for _, path in ipairs({ "dir-link", "container/alias" }) do
    local row = assert(frame:position(resources[path]:node()))
    t.assert_eq(resources[path]:node(), frame:node_at(row), "link owns its displayed row")
    t.assert_true(row ~= frame:position(resources[path .. "/nested"]:node()), "child stays separate")
  end
  t.assert_true(frame:position(resources.container:node()) ~= frame:position(resources["container/alias"]:node()))
  local ordinary = assert(frame:position(resources["target/nested"]:node()))
  t.assert_eq("target/nested", frame:rows(ordinary, ordinary).labels[1], "ordinary directories still compress")
  await(session:navigate(resources["dir-link"]:node(), false))
  t.wait_until(function()
    return view:frame():header().root.node == resources["dir-link"]:node()
  end, 10000)
end)

t:test("file and dangling-link roots are rejected without changing the display root", function()
  local root = directory()
  local widget = support.widget(root)
  local session, view = widget:context()
  local original = view:frame():header().root.node
  for _, path in ipairs({ "plain.lua", "file-link.lua", "broken-link" }) do
    local resource = await(session.data:resolve(root .. "/" .. path))
    local future = session:navigate(resource:node(), false)
    t.wait_until(function()
      return future:is_done()
    end, 10000)
    t.assert_false(future:is_failed(), future:get_error())
    t.assert_eq("Rejected", future:get_result().kind)
    t.assert_eq(original, view:frame():header().root.node)
  end
end)

t:test("refresh updates link identity after same-name replacements in both directions", function()
  local root = directory()
  local widget = support.widget(root)
  local session = widget:context()
  for _, case in ipairs({ { "file-link.lua", false }, { "dir-link", true } }) do
    local path = root .. "/" .. case[1]
    local old = await(session.data:resolve(path))
    assert(vim.uv.fs_unlink(path))
    if case[2] then
      assert(vim.uv.fs_mkdir(path, 448))
    else
      support.write(path)
    end
    await(session:refresh())
    local regular = await(session.data:resolve(path))
    t.assert_eq(case[2] and "directory" or "file", regular:info().kind)
    t.assert_true(old:node() ~= regular:node(), "replacement has a new resource occurrence")
    if case[2] then
      assert(vim.uv.fs_rmdir(path))
    else
      assert(vim.uv.fs_unlink(path))
    end
    assert(vim.uv.fs_symlink(case[2] and "target" or "plain.lua", path, { dir = case[2] }))
    await(session:refresh())
    t.assert_eq("link", await(session.data:resolve(path)):info().kind)
  end
end)

t:test("dangling links remain links when their directory targets appear and disappear", function()
  local root = directory()
  local widget = support.widget(root)
  local session = widget:context()
  local before = await(session.data:resolve(root .. "/broken-link"))
  assert(vim.uv.fs_mkdir(root .. "/missing", 448))
  await(session:refresh())
  local present = await(session.data:resolve(root .. "/broken-link"))
  t.assert_eq("link", present:info().kind)
  t.assert_true(present:info().directory)
  t.assert_eq(before:node(), present:node())
  assert(vim.uv.fs_rmdir(root .. "/missing"))
  await(session:refresh())
  local missing = await(session.data:resolve(root .. "/broken-link"))
  t.assert_eq("link", missing:info().kind)
  t.assert_false(missing:info().directory)
end)

t:test("real UI separates file icons from right-aligned links and preserves Git tint over diagnostics", function()
  local root = directory()
  local ui = require("__test__.support.ui").new()
  t:defer(function()
    ui:close()
  end)
  ui:rpc("nvim_ui_attach", 100, 30, { rgb = true, ext_linegrid = true })
  ui:rpc(
    "nvim_exec_lua",
    [=[
    local root, path = ...
    vim.opt.runtimepath:prepend(root)
    local suffix = vim.uv.os_uname().sysname == "Darwin" and "dylib" or "so"
    yoz = assert(package.loadlib(root .. "/rust/target/debug/libyoz." .. suffix, "luaopen_yoz"))()
    stl, dot, era = require("stl"), require("dot"), require("era")
    dot.path.workspace = function() return path end
    dot.path.is_git_repo = function() return false end
    errors, links, icons, names = {}, {}, {}, {}
    stl.reporter.warn = function(value) errors[#errors + 1] = value.message end
    stl.reporter.error = function(value) errors[#errors + 1] = value.message end
    stl.reporter.info = function() end
    local namespace = vim.api.nvim_create_namespace("era.explorer")
    local mark = vim.api.nvim_buf_set_extmark
    vim.api.nvim_buf_set_extmark = function(bufnr, ns, row, col, options)
      if ns == namespace and view and bufnr == view.bufnr then
        local frame = view:frame()
        local info = session.data:inspect(frame:source(), frame:node_at(row + 1)):info()
        if options.virt_text_pos == "right_align" then
          links[info.label] = options
        elseif options.virt_text_pos == "overlay" then
          icons[info.label] = options.virt_text[1]
        elseif options.hl_group then
          names[info.label] = options.hl_group
        end
      end
      return mark(bufnr, ns, row, col, options)
    end
    widget = require("era.m.explorer.widget").new({ name = "symlink-ui", root = path })
    widget:focus()
    assert(vim.wait(10000, function()
      local current = widget._views[vim.api.nvim_get_current_tabpage()]
      return current and current:frame() and current:frame():header().row_count == 6
    end))
    session, view = widget:context()
  ]=],
    { assert(vim.uv.cwd()), root }
  )
  t.wait_until(function()
    ui:rpc("nvim_command", "redraw")
    return ui:rpc(
      "nvim_exec_lua",
      "return links['dir-link'] ~= nil and links['file-link.lua'] ~= nil and links['broken-link'] ~= nil",
      {}
    )
  end, 10000)
  t.assert_true(ui:rpc("nvim_exec_lua", "return links['plain.lua'] == nil and links.target == nil", {}))
  t.assert_true(
    ui:rpc("nvim_exec_lua", "return icons['file-link.lua'][1] == stl.fileicon.get_file_icon('file-link.lua')", {})
  )
  t.assert_false(
    ui:rpc(
      "nvim_exec_lua",
      "return table.concat(vim.api.nvim_buf_get_lines(view.bufnr, 0, -1, true)):find('', 1, true) ~= nil",
      {}
    )
  )
  for _, case in ipairs({
    { git = 0, expected = "m_ex_symlink" },
    { git = 2, expected = "m_ex_symlink_untracked" },
    { git = 4, unstaged = true, expected = "m_ex_symlink_unstaged" },
    { git = 16, staged = true, expected = "m_ex_symlink_staged" },
    { git = 260, unstaged = true, expected = "m_ex_symlink_ignored" },
    { git = 8, staged = true, expected = "m_ex_symlink_delete" },
    { git = 4, staged = true, unstaged = true, expected = "m_ex_symlink_unstaged" },
    { git = 1, staged = true, unstaged = true, expected = "m_ex_symlink_unmerged" },
  }) do
    local rendered = ui:rpc(
      "nvim_exec_lua",
      [=[
      local case = ...
      local frame = view:frame()
      local rows = {}
      for row = 1, frame:header().row_count do
        rows[row] = { git = case.git, staged = case.staged, unstaged = case.unstaged, diagnostics = { 1, 0, 0, 0 } }
      end
      view._filetree_annotations = { frame = frame:id(), first = 1, rows = rows }
      view._filetree_annotation_data = frame:header().data_revision
      view._filetree_annotation_layout = frame:header().layout_revision
      links, icons, names = {}, {}, {}
      vim.cmd("redraw!")
      return { links = links, names = names }
    ]=],
      { case }
    )
    for _, name in ipairs({ "dir-link", "file-link.lua", "broken-link" }) do
      local options = rendered.links[name]
      t.assert_eq("  ", options.virt_text[1][1], "padding stays in one highlight chunk")
      t.assert_eq(case.expected, options.virt_text[1][2], name .. " Git tint")
      t.assert_eq("right_align", options.virt_text_pos)
      t.assert_eq("combine", options.hl_mode, "cursor background remains visible")
      t.assert_eq(
        case.git == 260 and "m_ex_ignored" or "DiagnosticError",
        rendered.names[name],
        name .. "/" .. case.expected .. " name color"
      )
    end
  end
  t.assert_eq(0, ui:rpc("nvim_exec_lua", "return #errors", {}))
  ui:rpc("nvim_exec_lua", "widget:dispose()", {})
end)

t:run()
