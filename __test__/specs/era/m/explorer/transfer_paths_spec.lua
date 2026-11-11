local t = require("__test__.support.harness").new()
local fixture = require("__test__.support.explorer").new(t)
local await, selected, write = fixture.await, fixture.selected, fixture.write

---@param widget                        era.m.explorer.Widget
---@param path                          string
---@return nil
local function cursor(widget, path)
  fixture.cursor(widget, path)
  local session, view = widget:context()
  t.wait_until(function()
    return session.state:native():applicable(view:frame())
  end, 10000)
end

t:test("copy and move defaults keep Unix filename components intact", function()
  if stl.env.IS_WIN then
    t.skip("a backslash is a path separator on Windows")
  end
  local base = t:tempdir()
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
  await(widget:action():transfer("copy"))
  fixture.idle(widget)
  t.assert_eq([[work\space/a\b-copy.txt]], prompts[1])
  t.assert_true(vim.uv.fs_stat(literal .. "/a\\b-copy.txt") ~= nil)
  t.assert_eq(nil, vim.uv.fs_stat(base .. "/work/space/a/b-copy.txt"))
  cursor(widget, source)
  await(widget:action():transfer("cut"))
  fixture.idle(widget)
  t.assert_eq([[work\space/a\b.txt]], prompts[2])
  t.assert_true(vim.uv.fs_stat(source) ~= nil, "unchanged move default must not relocate the source")
  t.assert_eq(nil, vim.uv.fs_stat(base .. "/work/space/a/b.txt"))
end)

t:test("path and directory transfers preserve raw names and create missing parents", function()
  if stl.env.IS_WIN then
    t.skip("needs raw Unix filename bytes")
  end
  local base = t:tempdir()
  local source = base .. "/source\\name.txt"
  fixture.write(source)
  local widget = fixture.widget(base)
  t:patch_table(dot.path, "cwd", function()
    return base
  end)
  cursor(widget, source)
  await(widget:action():operate({ kind = "copy_to_path", path = [[new\parent/deep/copy\name.txt]] }))
  fixture.idle(widget)
  local copied = base .. [[/new\parent/deep/copy\name.txt]]
  t.assert_eq("test", vim.fn.readfile(copied)[1])
  t.assert_eq(nil, vim.uv.fs_stat(base .. "/new/parent"))
  local destination = base .. "/destination\\dir"
  assert(vim.uv.fs_mkdir(destination, 448))
  cursor(widget, source)
  await(widget:action():operate({ kind = "move_to_directory", path = destination }))
  fixture.idle(widget)
  t.assert_eq(nil, vim.uv.fs_stat(source))
  t.assert_eq("test", vim.fn.readfile(destination .. "/source\\name.txt")[1])
  local session = widget:context()
  t.assert_eq(destination .. "/source\\name.txt", session.results[1].target)
end)

t:test("filesystem resolves parent components after following a directory link", function()
  if stl.env.IS_WIN then
    t.skip("needs Unix symbolic links and aliases")
  end
  local base = t:tempdir()
  assert(vim.uv.fs_mkdir(base .. "/physical", 448))
  assert(vim.uv.fs_mkdir(base .. "/physical/inner", 448))
  assert(vim.uv.fs_symlink("physical/inner", base .. "/link"))
  fixture.write(base .. "/source")
  local widget = fixture.widget(base)
  t:patch_table(dot.path, "cwd", function()
    return base
  end)
  cursor(widget, base .. "/source")
  await(widget:action():operate({ kind = "copy_to_path", path = "link/../copied" }))
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
      t.skip("needs Unix symbolic links and aliases")
    end
    local base = require("ux.filetree.path").from_os(t:tempdir())
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
    await(widget:action():operate({ kind = case.kind, path = case.target }))
    fixture.idle(widget)
    t.assert_eq("test", vim.fn.readfile(base .. "/dest/a")[1])
    t.assert_eq(case.kind == "copy_to_path", vim.uv.fs_stat(base .. "/source") ~= nil)
    t.assert_eq(nil, vim.uv.fs_stat(base .. "/a"), "parent components must follow the link's actual target")
    t.assert_eq(0, widget:context()._counts.failed)
  end)
end

t:test("copy and move to a complete path create parents and keep rename within the current parent", function()
  local path = t:tempdir()
  write(path .. "/a")
  local widget = fixture.widget(path)
  local data = widget:context().data
  local resolve = data.resolve
  t:patch_table(data, "resolve", function(self, filepath)
    return resolve(self, filepath):map(function(value)
      if type(value) == "table" and value.kind == "Rejected" then
        value.error.message = "resource unavailable; diagnostic wording is not an error code"
      end
      return value
    end)
  end)
  fixture.cursor(widget, path .. "/a")
  await(widget:action():operate({ kind = "copy_to_path", path = path .. "/new/nested/duplicate" }))
  fixture.idle(widget)
  t.assert_true(vim.uv.fs_stat(path .. "/a") ~= nil)
  t.assert_true(vim.uv.fs_stat(path .. "/new/nested/duplicate") ~= nil)
  fixture.cursor(widget, path .. "/a")
  await(widget:action():operate({ kind = "move_to_path", path = path .. "/moved/renamed" }))
  fixture.idle(widget)
  t.assert_eq(nil, vim.uv.fs_stat(path .. "/a"))
  t.assert_true(vim.uv.fs_stat(path .. "/moved/renamed") ~= nil)
  await(widget:reveal(path .. "/moved/renamed"))
  fixture.cursor(widget, path .. "/moved/renamed")
  t:patch_table(vim.ui, "input", function(options, done)
    t.assert_eq("renamed", options.default)
    done("final")
  end)
  await(widget:action():operate({ kind = "rename" }))
  fixture.idle(widget)
  t.assert_true(vim.uv.fs_stat(path .. "/moved/final") ~= nil)
end)

t:test("a non-missing resolve error cannot authorize creating parents through its message", function()
  local path = t:tempdir()
  write(path .. "/a")
  local widget = fixture.widget(path)
  fixture.cursor(widget, path .. "/a")
  local data = widget:context().data
  local resolve = data.resolve
  t:patch_table(data, "resolve", function(self, filepath)
    if filepath == path .. "/blocked" then
      return stl.c.Future.resolve({
        kind = "Rejected",
        error = { code = "ProviderError", message = "unrelated failure mentioning kind=NotFound" },
      })
    end
    return resolve(self, filepath)
  end)
  local ok = t.settle(widget:action():operate({ kind = "copy_to_path", path = path .. "/blocked/copied" }))
  t.assert_false(ok)
  t.assert_nil(vim.uv.fs_stat(path .. "/blocked"))
  fixture.idle(widget)
end)

t:test("copy to an alias inside the source is rejected before creating missing parents", function()
  if stl.env.IS_WIN then
    t.skip("needs Unix symbolic links and aliases")
  end
  local path = t:tempdir()
  assert(vim.uv.fs_mkdir(path .. "/source", 448))
  write(path .. "/source/a")
  assert(vim.uv.fs_symlink("source", path .. "/alias"))
  local widget = fixture.widget(path)
  fixture.cursor(widget, path .. "/source")
  local ok, err = t.settle(widget:action():operate({ kind = "copy_to_path", path = path .. "/alias/created/copy" }))
  t.assert_false(ok)
  t.assert_true(err:find("inside its source", 1, true) ~= nil)
  t.assert_eq(nil, vim.uv.fs_stat(path .. "/source/created"))
  fixture.idle(widget)
end)

t:test("accepting the copy default duplicates the cursor file and cut uses the supplied path", function()
  local path = t:tempdir()
  fixture.write(path .. "/a.lua")
  local widget = fixture.widget(path)
  t:patch_table(vim.ui, "input", function(options, done)
    done(options.default)
  end)
  fixture.cursor(widget, path .. "/a.lua")
  selected(widget, nil, 0)
  await(widget:action():transfer("copy"))
  fixture.idle(widget)
  t.assert_true(vim.uv.fs_stat(path .. "/a-copy.lua") ~= nil)
  t.assert_true(vim.uv.fs_stat(path .. "/a.lua") ~= nil)
  t:patch_table(vim.ui, "input", function(_, done)
    done(path .. "/moved.lua")
  end)
  fixture.cursor(widget, path .. "/a.lua")
  selected(widget, nil, 0)
  await(widget:action():transfer("cut"))
  fixture.idle(widget)
  t.assert_nil(vim.uv.fs_stat(path .. "/a.lua"))
  t.assert_true(vim.uv.fs_stat(path .. "/moved.lua") ~= nil)
end)

t:run()
