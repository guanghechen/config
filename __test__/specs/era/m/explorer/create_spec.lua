local t = require("__test__.support.harness").new()
local fixture = require("__test__.support.explorer").new(t)
local await = fixture.await

t:test("new relative file creates parents, reveals it, and opens in a source window", function()
  local path = t:tempdir()
  local target = vim.api.nvim_get_current_win()
  t:patch_table(dot.win, "pick_sourcefile", function()
    return target
  end)
  t:patch_table(vim.ui, "input", function(_, done)
    done("notes/todo")
  end)
  local widget = fixture.widget(path)
  await(widget:action():create(false))
  fixture.idle(widget)
  t.wait_until(function()
    return vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(target)) == vim.uv.fs_realpath(path .. "/notes/todo")
  end, 10000)
  t.assert_eq(target, vim.api.nvim_get_current_win())
  t.assert_true(vim.uv.fs_stat(path .. "/notes/todo") ~= nil)
end)

t:test("creation through a directory link reveals the created logical occurrence", function()
  local path = t:tempdir()
  assert(vim.uv.fs_mkdir(path .. "/target", 448))
  assert(vim.uv.fs_symlink("target", path .. "/alias", { dir = true }))
  local target = vim.api.nvim_get_current_win()
  t:patch_table(dot.win, "pick_sourcefile", function()
    return target
  end)
  t:patch_table(vim.ui, "input", function(options, done)
    done(options.default .. "notes/todo")
  end)
  local widget = fixture.widget(path)
  fixture.cursor(widget, path .. "/alias")
  await(widget:action():create(false))
  fixture.idle(widget)
  t.wait_until(function()
    return vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(target))
        == vim.uv.fs_realpath(path .. "/target/notes/todo")
      and widget:get_cursor_filepath() == path .. "/alias/notes/todo"
  end, 10000)
  t.assert_eq(path, widget:get_root_filepath())
  t.assert_eq(target, vim.api.nvim_get_current_win())
end)

t:test("editing the create directory prefix chooses a path under the captured display root", function()
  local path = t:tempdir()
  assert(vim.uv.fs_mkdir(path .. "/folder", 448))
  local widget = fixture.widget(path)
  fixture.cursor(widget, path .. "/folder")
  t:patch_table(vim.ui, "input", function(options, done)
    t.assert_eq("Create file: ", options.prompt)
    t.assert_eq("folder/", options.default)
    done("other/new.txt")
  end)
  await(widget:action():create(false))
  fixture.idle(widget)
  t.assert_true(vim.uv.fs_stat(path .. "/other/new.txt") ~= nil)
  t.assert_eq(nil, vim.uv.fs_stat(path .. "/folder/other/new.txt"))
end)

t:test("create prefixes respect native root separators and preserve the captured directory", function()
  local Session = require("era.m.explorer.session")
  local Jobs = require("era.m.explorer.jobs")
  local state = fixture.widget(t:tempdir()):context().state
  for _, case in ipairs({
    { windows = true, root = "C:\\", destination = "C:\\foo", default = "foo/" },
    { windows = true, root = "C:\\", destination = "C:\\", default = "" },
    { windows = true, root = "C:\\root", destination = "C:\\root\\foo", default = "foo/" },
    { windows = true, root = "\\\\server\\share\\", destination = "\\\\server\\share\\foo", default = "foo/" },
    { windows = true, root = "C:/", destination = "C:/foo", default = "foo/" },
    { windows = false, root = "/", destination = "/foo", default = "foo/" },
    { windows = false, root = "/root\\", destination = "/root\\/foo", default = "foo/" },
  }) do
    t:patch_table(stl.env, "IS_WIN", case.windows)
    local destination = {
      path = function()
        return case.destination
      end,
    }
    local root = {
      path = function()
        return case.root
      end,
    }
    local default, captured
    t:patch_table(vim.ui, "input", function(options, done)
      default = options.default
      done(default .. "new.txt")
    end)
    local session = {
      busy = function()
        return false
      end,
      cursor = function()
        return nil
      end,
      target = function()
        return destination
      end,
      root = function()
        return root
      end,
      notify = function() end,
      _release = function() end,
      report = function() end,
      await = Session.await,
      state = state,
      native = {
        start_create = function(_, options)
          captured = options
          error("stop before native create", 0)
        end,
      },
    }
    local ok, err = t.settle(Jobs.start(session, {
      frame = function()
        return {}
      end,
    }, { kind = "create" }))
    t.assert_false(ok)
    t.assert_true(err:find("stop before native create", 1, true) == 1, err)
    t.assert_eq(case.default, default, case.destination)
    t.assert_eq(destination, captured.target)
    t.assert_eq("new.txt", captured.path)
    t.assert_false(state:status().locked)
  end
end)

t:test("an unchanged create prefix cannot retarget a replaced destination directory", function()
  local path = t:tempdir()
  assert(vim.uv.fs_mkdir(path .. "/folder", 448))
  local widget = fixture.widget(path)
  fixture.cursor(widget, path .. "/folder")
  local answer
  t:patch_table(vim.ui, "input", function(options, done)
    t.assert_eq("folder/", options.default)
    answer = done
  end)
  local creating = widget:action():create(false)
  t.wait_until(function()
    return answer ~= nil
  end, 10000)
  assert(vim.uv.fs_rename(path .. "/folder", path .. "/original"))
  assert(vim.uv.fs_mkdir(path .. "/folder", 448))
  answer("folder/new.txt")
  pcall(await, creating)
  fixture.idle(widget)
  t.assert_eq(nil, vim.uv.fs_stat(path .. "/folder/new.txt"))
  t.assert_eq(nil, vim.uv.fs_stat(path .. "/original/new.txt"))
end)

t:run()
