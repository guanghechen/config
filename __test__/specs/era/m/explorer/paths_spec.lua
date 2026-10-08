---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.specs.era.m.explorer.paths" ---@type string

local fixture = require("__test__.support.explorer").new("era.m.explorer.paths")
local t, await = fixture.t, fixture.await

---@param widget                        era.m.explorer.Widget
---@param path                          string
---@return nil
local function cursor(widget, path)
  fixture.cursor(widget, path)
  local session, view = widget:context()
  t.wait_until(function()
    return session.state._native:applicable(view:frame())
  end, 10000)
end

t:test("copy and move defaults keep Unix filename components intact", function()
  if stl.env.IS_WIN then
    return
  end
  local base = assert(vim.uv.fs_realpath(fixture.directory()))
  local literal = base .. "/work\\space"
  assert(vim.uv.fs_mkdir(literal, 448))
  assert(vim.uv.fs_mkdir(base .. "/work", 448))
  assert(vim.uv.fs_mkdir(base .. "/work/space", 448))
  local source = literal .. "/a\\b.txt"
  fixture.write(source)
  t:patch_table(dot.path, "cwd", function()
    return base
  end)
  local widget = fixture.widget(literal)
  local prompts = {}
  t:patch_table(vim.ui, "input", function(options, done)
    prompts[#prompts + 1] = options.default
    done(options.default)
  end)
  cursor(widget, source)
  await(widget._action:transfer("copy"))
  fixture.idle(widget)
  t.assert_eq([[work\space/a\b-copy.txt]], prompts[1])
  t.assert_true(vim.uv.fs_stat(literal .. "/a\\b-copy.txt") ~= nil)
  t.assert_eq(nil, vim.uv.fs_stat(base .. "/work/space/a/b-copy.txt"))
  cursor(widget, source)
  await(widget._action:transfer("cut"))
  fixture.idle(widget)
  t.assert_eq([[work\space/a\b.txt]], prompts[2])
  t.assert_true(vim.uv.fs_stat(source) ~= nil, "unchanged move default must not relocate the source")
  t.assert_eq(nil, vim.uv.fs_stat(base .. "/work/space/a/b.txt"))
end)

t:test("path and directory transfers preserve raw names and create missing parents", function()
  if stl.env.IS_WIN then
    return
  end
  local base = assert(vim.uv.fs_realpath(fixture.directory()))
  local source = base .. "/source\\name.txt"
  fixture.write(source)
  local widget = fixture.widget(base)
  t:patch_table(dot.path, "cwd", function()
    return base
  end)
  cursor(widget, source)
  await(widget._action:operate({ kind = "copy_to_path", path = [[new\parent/deep/copy\name.txt]] }))
  fixture.idle(widget)
  local copied = base .. [[/new\parent/deep/copy\name.txt]]
  t.assert_eq("test", vim.fn.readfile(copied)[1])
  t.assert_eq(nil, vim.uv.fs_stat(base .. "/new/parent"))
  local destination = base .. "/destination\\dir"
  assert(vim.uv.fs_mkdir(destination, 448))
  cursor(widget, source)
  await(widget._action:operate({ kind = "move_to_directory", path = destination }))
  fixture.idle(widget)
  t.assert_eq(nil, vim.uv.fs_stat(source))
  t.assert_eq("test", vim.fn.readfile(destination .. "/source\\name.txt")[1])
  local session = widget:context()
  t.assert_eq(destination .. "/source\\name.txt", session.results[1].target)
end)

t:test("filesystem resolves parent components after following a directory link", function()
  if stl.env.IS_WIN then
    return
  end
  local base = assert(vim.uv.fs_realpath(fixture.directory()))
  assert(vim.uv.fs_mkdir(base .. "/physical", 448))
  assert(vim.uv.fs_mkdir(base .. "/physical/inner", 448))
  assert(vim.uv.fs_symlink("physical/inner", base .. "/link"))
  fixture.write(base .. "/source")
  local widget = fixture.widget(base)
  t:patch_table(dot.path, "cwd", function()
    return base
  end)
  cursor(widget, base .. "/source")
  await(widget._action:operate({ kind = "copy_to_path", path = "link/../copied" }))
  fixture.idle(widget)
  t.assert_eq("test", vim.fn.readfile(base .. "/physical/copied")[1])
  t.assert_eq(nil, vim.uv.fs_stat(base .. "/copied"))
end)

for _, case in ipairs({
  { kind = "copy_to_path", target = "dest/." },
  { kind = "move_to_path", target = "dest/." },
  { kind = "copy_to_path", target = "link/..", link = true },
}) do
  t:test(case.kind .. " resolves a terminal directory component in " .. case.target, function()
    if case.link and stl.env.IS_WIN then
      return
    end
    local base = require("ux.filetree.path").from_os(assert(vim.uv.fs_realpath(fixture.directory())))
    assert(vim.uv.fs_mkdir(base .. "/source", 448))
    fixture.write(base .. "/source/a")
    assert(vim.uv.fs_mkdir(base .. "/dest", 448))
    if case.link then
      assert(vim.uv.fs_mkdir(base .. "/dest/inner", 448))
      assert(vim.uv.fs_symlink("dest/inner", base .. "/link"))
    end
    local widget = fixture.widget(base)
    t:patch_table(dot.path, "cwd", function()
      return base
    end)
    t:patch_table(vim.ui, "input", function(_, done)
      done("y")
    end)
    cursor(widget, base .. "/source")
    await(widget._action:operate({ kind = case.kind, path = case.target }))
    fixture.idle(widget)
    t.assert_eq("test", vim.fn.readfile(base .. "/dest/a")[1])
    t.assert_eq(case.kind == "copy_to_path", vim.uv.fs_stat(base .. "/source") ~= nil)
    t.assert_eq(nil, vim.uv.fs_stat(base .. "/a"), "parent components must follow the link's actual target")
    t.assert_eq(0, widget:context()._counts.failed)
  end)
end

t:test("default reveal and Copy Path preserve a Unix backslash name", function()
  if stl.env.IS_WIN then
    return
  end
  local base = assert(vim.uv.fs_realpath(fixture.directory()))
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
    await(widget._action:auxiliary("copy_path"))
    t.assert_eq(pair[2], copied)
  end
end)

t:run()
