---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.specs.era.m.explorer.info" ---@type string

local fixture = require("__test__.support.explorer").new("era.m.explorer.info")
local t, await = fixture.t, fixture.await
local Fileinfo = require("era.view.fileinfo")

---@return era.view.Fileinfo[]
local function capture_panels()
  local panels = {}
  local new = Fileinfo.new
  t:patch_table(Fileinfo, "new", function(props)
    local panel = new(props)
    t:defer(function()
      panel:dispose()
    end)
    panels[#panels + 1] = panel
    return panel
  end)
  return panels
end

t:test("File Info displays the cursor file while preserving an unrelated copy selection", function()
  local path = fixture.directory()
  for _, name in ipairs({ "a", "b", "c" }) do
    fixture.write(path .. "/" .. name)
  end
  local widget = fixture.widget(path)
  local session, view = widget:context()
  fixture.cursor(widget, path .. "/a")
  vim.cmd.normal({ args = { "Vj" }, bang = true })
  local marked = await(widget._action:mark("copy"))
  t.wait_until(function()
    return session.state._native:applicable(view:frame(), marked.revisions.commit)
  end, 10000)
  fixture.cursor(widget, path .. "/c")
  local panels = capture_panels()
  await(widget._action:auxiliary("info"))
  t.assert_eq(1, #panels)
  local panel = panels[1]
  t.assert_true(panel:isvisible())
  local body = table.concat(vim.api.nvim_buf_get_lines(panel._bufnr, 0, -1, false), "\n")
  t.assert_true(body:find("Path%s*:%s*c\n") ~= nil, body)
  t.assert_true(body:find("Size%s*:%s*4 B\n") ~= nil, body)
  t.assert_eq(2, await(session.state:inspect_selection()).subtree_roots:len())
  t.assert_eq("copy", session:mode())
  panel:close()
  t.assert_eq(view.winnr, vim.api.nvim_get_current_win())
end)

t:test("File Info captures its target and ignores a superseded request after its panel closes", function()
  local path = fixture.directory()
  fixture.write(path .. "/a")
  fixture.write(path .. "/b")
  local widget = fixture.widget(path)
  local session = widget:context()
  local a = fixture.cursor(widget, path .. "/a")
  local details = await(session.data:details(a))
  local pending = {}
  t:patch_table(session.data, "details", function(_, resource)
    local future, resolve = stl.c.Future.new_with_resolver()
    pending[#pending + 1] = { path = resource:path(), resolve = resolve }
    return future
  end)
  local panels = capture_panels()
  local first = widget._action:auxiliary("info")
  t.wait_until(function()
    return #pending == 1
  end, 10000)
  fixture.cursor(widget, path .. "/b")
  local second = widget._action:auxiliary("info")
  t.wait_until(function()
    return #pending == 2
  end, 10000)
  t.assert_eq(path .. "/a", pending[1].path)
  t.assert_eq(path .. "/b", pending[2].path)
  pending[2].resolve(details)
  await(second)
  t.assert_eq(1, #panels)
  t.assert_eq(path .. "/b", panels[1]._filepath)
  panels[1]:close()
  pending[1].resolve(details)
  await(first)
  t.assert_eq(1, #panels, "the old request must not reopen its panel")
end)

t:test("a delayed File Info request preserves its cursor target and respects lost focus", function()
  for _, leave in ipairs({ false, true }) do
    local path = fixture.directory()
    fixture.write(path .. "/a")
    fixture.write(path .. "/b")
    local source_winnr = vim.api.nvim_get_current_win()
    local widget = fixture.widget(path)
    local session = widget:context()
    local a = fixture.cursor(widget, path .. "/a")
    local details = await(session.data:details(a))
    local waiting, resolve = stl.c.Future.new_with_resolver()
    t:patch_table(session.data, "details", function()
      return waiting
    end)
    local panels = capture_panels()
    local future = widget._action:auxiliary("info")
    fixture.cursor(widget, path .. "/b")
    if leave then
      vim.api.nvim_set_current_win(source_winnr)
    end
    resolve(details)
    await(future)
    t.assert_eq(leave and 0 or 1, #panels)
    if not leave then
      t.assert_eq(path .. "/a", panels[1]._filepath)
      panels[1]:close()
    end
    widget:dispose()
  end
end)

t:test("leaving and returning permanently invalidates pending File Info, including a late rejection", function()
  for _, rejected in ipairs({ false, true }) do
    local path = fixture.directory()
    fixture.write(path .. "/a")
    local source_winnr = vim.api.nvim_get_current_win()
    local widget = fixture.widget(path)
    local session, view = widget:context()
    local a = fixture.cursor(widget, path .. "/a")
    local details = await(session.data:details(a))
    local waiting, resolve = stl.c.Future.new_with_resolver()
    t:patch_table(session.data, "details", function()
      return waiting
    end)
    local before = #vim.api.nvim_get_autocmds({ buf = view.bufnr, event = { "WinLeave", "BufLeave" } })
    local panels = capture_panels()
    local future = widget._action:auxiliary("info")
    vim.api.nvim_set_current_win(source_winnr)
    vim.api.nvim_set_current_win(view.winnr)
    resolve(
      rejected and { kind = "Rejected", error = { code = "MissingNode", message = "source disappeared" } } or details
    )
    await(future)
    t.assert_eq(0, #panels)
    t.assert_eq(view.winnr, vim.api.nvim_get_current_win())
    t.assert_eq(before, #vim.api.nvim_get_autocmds({ buf = view.bufnr, event = { "WinLeave", "BufLeave" } }))
    widget:dispose()
  end
end)

t:test("File Info displays supplied metadata and wraps long escaped paths within the screen", function()
  local path = fixture.directory()
  t:patch_table(dot.path, "workspace", function()
    return path
  end)
  local filepath = path .. "-sibling/" .. string.rep("中", 100) .. "\nfile"
  local panel = Fileinfo.new({
    filepath = filepath,
    kind = "file",
    details = { size = 1048576, permissions = "rw-r--r--", mode = "0644" },
  })
  t:defer(function()
    panel:dispose()
  end)
  panel:open()
  t.assert_true(panel:isvisible(), "opening supplied metadata must not stat the path")
  local body = table.concat(vim.api.nvim_buf_get_lines(panel._bufnr, 0, -1, false), "\n")
  t.assert_true(body:find(vim.fn.strtrans(filepath), 1, true) ~= nil, "workspace prefixes must match a path boundary")
  t.assert_true(body:find("1.0 MiB (1048576 bytes)", 1, true) ~= nil)
  t.assert_true(vim.api.nvim_win_get_width(panel._winnr) <= vim.o.columns - 4)
  t.assert_true(vim.api.nvim_win_get_height(panel._winnr) <= vim.o.lines - 4)
  t.assert_true(vim.api.nvim_get_option_value("wrap", { win = panel._winnr }))
  t.assert_false(vim.api.nvim_get_option_value("modifiable", { buf = panel._bufnr }))
end)

t:run()
