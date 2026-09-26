---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.specs.era.m.explorer.buffers" ---@type string

local fixture = require("__test__.support.explorer").new("era.m.explorer.buffers")
local t, await = fixture.t, fixture.await
local buffers = require("era.m.explorer.buffers")

for _, case in ipairs({
  {
    name = "Windows drive",
    windows = true,
    source = [[C:\alias\old]],
    target = [[C:\alias\new]],
    physical = [[\\?\C:\work\old]],
    destination = [[\\?\C:\work\new]],
    from = "C:/work/old",
    to = "C:/work/new",
  },
  {
    name = "Windows UNC",
    windows = true,
    source = [[\\server\alias\old]],
    target = [[\\server\alias\new]],
    physical = [[\\?\UNC\server\share\old]],
    destination = [[\\?\UNC\server\share\new]],
    from = "//server/share/old",
    to = "//server/share/new",
  },
  {
    name = "Windows UNC file",
    windows = true,
    single_file = true,
    source = [[\\server\share\a.txt]],
    target = [[\\server\share\b.txt]],
    physical = [[\\?\UNC\server\share\a.txt]],
    destination = [[\\?\UNC\server\share\b.txt]],
    from = "//server/share/a.txt",
    to = "//server/share/b.txt",
  },
  {
    name = "Windows drive move with an unrelated UNC buffer",
    windows = true,
    unrelated = "//server/share/unrelated.txt",
    source = [[C:\work\a.txt]],
    target = [[C:\work\b.txt]],
    physical = [[\\?\C:\work\a.txt]],
    destination = [[\\?\C:\work\b.txt]],
    from = "C:/work/a.txt",
    to = "C:/work/b.txt",
  },
  {
    name = "Unix literal backslash and filename bytes",
    windows = false,
    source = "/alias/old\\" .. string.char(255),
    target = "/alias/new\\" .. string.char(255),
    physical = "/work/old\\" .. string.char(255),
    destination = "/work/new\\" .. string.char(255),
    from = "/work/old\\" .. string.char(255),
    to = "/work/new\\" .. string.char(255),
  },
}) do
  t:test(case.name .. " paths agree across LSP preparation and alias buffer synchronization", function()
    t:patch_table(stl.env, "IS_WIN", case.windows)
    if case.windows then
      local restore = t:patch_table(vim.uv, "os_uname", function()
        return { sysname = "Windows_NT" }
      end)
      local windows_fs = dofile(vim.env.VIMRUNTIME .. "/lua/vim/fs.lua")
      restore()
      t:patch_table(vim.fs, "dirname", windows_fs.dirname)
    end
    local bufnr = vim.api.nvim_create_buf(true, false)
    t:defer(function()
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "unsaved content" })
    local suffix = case.single_file and "" or "/$literal space #文.lua"
    local name = case.unrelated or case.from .. suffix
    local get_name = vim.api.nvim_buf_get_name
    -- Emulate only the platform filename; the buffer and URI encoder are real.
    t:patch_table(vim.api, "nvim_buf_get_name", function(current)
      return current == bufnr and name or get_name(current)
    end)
    -- These synthetic platform paths test the editor boundary, not the host filesystem's rules.
    t:patch_table(yoz.fs, "entry_path", function(path)
      if case.windows and not (path:match("^%a:/") or path:match("^//[^/]+/[^/]+")) then
        return nil, "path must be absolute without parent components"
      end
      return path
    end)
    t:patch_table(yoz.fs, "path_suffix", function(base, path)
      if base == path then
        return ""
      elseif path:sub(1, #base + 1) == base .. "/" then
        return path:sub(#base + 2)
      end
    end)
    local renamed = {}
    t:patch_table(era.m.lsp.event, "rename_buf", function(from, to)
      renamed[#renamed + 1] = { from, to }
    end)
    local sent = {}
    t:patch_table(vim.lsp, "get_clients", function()
      return {
        {
          offset_encoding = "utf-16",
          supports_method = function()
            return true
          end,
          request = function(_, method, changes, done)
            sent[method] = changes
            done(nil, nil)
            return true, 1
          end,
          notify = function(_, method, changes)
            sent[method] = changes
          end,
        },
      }
    end)
    local confirmation = { token = "move", source = case.physical, target = case.destination }
    t.assert_true(await(buffers.prepare({
      status = function()
        return { confirmation = confirmation }
      end,
    }, confirmation)))
    buffers.sync({
      operation = "move",
      report = function(message)
        error(message)
      end,
    }, {
      status = "success",
      source = case.source,
      target = case.target,
      source_physical = case.physical,
      target_physical = case.destination,
    })
    local expected = {
      files = { { oldUri = vim.uri_from_fname(case.from), newUri = vim.uri_from_fname(case.to) } },
    }
    for _, method in ipairs({ "workspace/willRenameFiles", "workspace/didRenameFiles" }) do
      t.assert_true(vim.deep_equal(expected, sent[method]), method .. ": " .. vim.inspect(sent[method]))
    end
    local expected_renames = case.unrelated and {} or { { name, case.to .. suffix } }
    t.assert_true(vim.deep_equal(expected_renames, renamed))
    t.assert_eq(case.physical, confirmation.source)
    t.assert_eq(case.destination, confirmation.target)
    t.assert_true(vim.deep_equal({ "unsaved content" }, vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)))
    t.assert_true(vim.api.nvim_get_option_value("modified", { buf = bufnr }))
  end)
end

t:test("loaded rename round trips discard only empty placeholders and preserve unsaved undo history", function()
  local path = assert(vim.uv.fs_realpath(fixture.directory()))
  fixture.write(path .. "/a.txt")
  local bufnr = vim.fn.bufadd(path .. "/a.txt")
  vim.fn.bufload(bufnr)
  t:defer(function()
    for _, current in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_get_name(current):sub(1, #path + 1) == path .. "/" then
        vim.api.nvim_buf_delete(current, { force = true })
      end
    end
  end)
  local group = vim.api.nvim_create_augroup("test_explorer_move_cache", { clear = true })
  t:defer(function()
    vim.api.nvim_del_augroup_by_id(group)
  end)
  vim.api.nvim_create_autocmd("BufFilePost", {
    group = group,
    callback = function(event)
      stl.nvim.buf.on_buf_open(event.buf, vim.api.nvim_buf_get_name(event.buf))
    end,
  })
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "unsaved content" })
  local undo = vim.api.nvim_buf_call(bufnr, vim.fn.undotree)
  local widget = fixture.widget(path)
  for _, names in ipairs({ { "a.txt", "b.txt" }, { "b.txt", "a.txt" } }) do
    fixture.cursor(widget, path .. "/" .. names[1])
    await(widget._action:operate("move", { rename = true, name = names[2] }))
    fixture.idle(widget)
    t.assert_eq(path .. "/" .. names[2], vim.api.nvim_buf_get_name(bufnr))
    t.assert_eq("unsaved content", vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)[1])
    t.assert_true(vim.api.nvim_get_option_value("modified", { buf = bufnr }))
    t.assert_eq(undo.seq_cur, vim.api.nvim_buf_call(bufnr, vim.fn.undotree).seq_cur)
    t.assert_eq(nil, vim.b[bufnr].filetree_move_target)
    t.assert_eq("test", vim.fn.readfile(path .. "/" .. names[2])[1])
  end
  -- Neovim's :file protection remains: explicit user overwrite saves the renamed file.
  vim.api.nvim_buf_call(bufnr, function()
    vim.cmd.write({ bang = true })
  end)
  t.assert_eq("unsaved content", vim.fn.readfile(path .. "/a.txt")[1])
  t.assert_eq(nil, vim.uv.fs_stat(path .. "/b.txt"))
end)

for _, directory in ipairs({ false, true }) do
  t:test((directory and "directory" or "file") .. " moves reject a live target buffer before filesystem IO", function()
    local path = assert(vim.uv.fs_realpath(fixture.directory()))
    local source, target = path .. "/a.txt", path .. "/b.txt"
    if directory then
      assert(vim.uv.fs_mkdir(path .. "/old", 448))
      source, target = path .. "/old/a.txt", path .. "/new/a.txt"
    end
    fixture.write(source)
    local from = vim.fn.bufadd(source)
    vim.fn.bufload(from)
    local to = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_buf_set_name(to, target)
    vim.api.nvim_buf_set_lines(to, 0, -1, false, { "destination edits" })
    t:defer(function()
      for _, bufnr in ipairs({ from, to }) do
        if vim.api.nvim_buf_is_valid(bufnr) then
          vim.api.nvim_buf_delete(bufnr, { force = true })
        end
      end
    end)
    local widget = fixture.widget(path)
    fixture.cursor(widget, directory and path .. "/old" or source)
    await(widget._action:operate("move", { rename = true, name = directory and "new" or "b.txt" }))
    fixture.idle(widget)
    t.assert_true(vim.uv.fs_stat(source) ~= nil)
    t.assert_eq(nil, vim.uv.fs_stat(target))
    t.assert_eq(source, vim.api.nvim_buf_get_name(from))
    t.assert_eq("destination edits", vim.api.nvim_buf_get_lines(to, 0, -1, false)[1])
    t.assert_true(vim.api.nvim_get_option_value("modified", { buf = to }))
    t.assert_eq(0, widget._session._counts.success)
    t.assert_eq(1, widget._session._counts.skipped)
  end)
end

for _, directory in ipairs({ false, true }) do
  t:test(
    (directory and "directory" or "file") .. " move protects destination buffers when the source is unopened",
    function()
      local path = assert(vim.uv.fs_realpath(fixture.directory()))
      local source, destination = path .. "/a.txt", path .. "/b.txt"
      if directory then
        assert(vim.uv.fs_mkdir(path .. "/old", 448))
        source, destination = path .. "/old/a.txt", path .. "/new/a.txt"
      end
      fixture.write(source)
      local target = vim.api.nvim_create_buf(true, false)
      t:defer(function()
        vim.api.nvim_buf_delete(target, { force = true })
      end)
      vim.api.nvim_buf_set_name(target, destination)
      vim.api.nvim_buf_set_lines(target, 0, -1, false, { "destination edits" })
      local widget = fixture.widget(path)
      fixture.cursor(widget, directory and path .. "/old" or source)
      await(widget._action:operate("move", { rename = true, name = directory and "new" or "b.txt" }))
      fixture.idle(widget)
      t.assert_true(vim.uv.fs_stat(source) ~= nil)
      t.assert_eq(nil, vim.uv.fs_stat(destination))
      t.assert_eq("destination edits", vim.api.nvim_buf_get_lines(target, 0, -1, false)[1])
      t.assert_eq(0, widget._session._counts.success)
    end
  )
end

t:test("a destination buffer introduced by an LSP reply is checked again before IO", function()
  local path = assert(vim.uv.fs_realpath(fixture.directory()))
  fixture.write(path .. "/a.txt")
  local source = vim.fn.bufadd(path .. "/a.txt")
  vim.fn.bufload(source)
  local target
  t:defer(function()
    for _, bufnr in ipairs({ source, target }) do
      if vim.api.nvim_buf_is_valid(bufnr) then
        vim.api.nvim_buf_delete(bufnr, { force = true })
      end
    end
  end)
  local notifications = 0
  t:patch_table(vim.lsp, "get_clients", function(options)
    return options and options.bufnr and {}
      or {
        {
          offset_encoding = "utf-16",
          supports_method = function()
            return true
          end,
          request = function(_, _, _, done)
            vim.schedule(function()
              target = vim.api.nvim_create_buf(true, false)
              vim.api.nvim_buf_set_name(target, path .. "/b.txt")
              vim.api.nvim_buf_set_lines(target, 0, -1, false, { "LSP destination edits" })
              done(nil, nil)
            end)
            return true, 1
          end,
          notify = function()
            notifications = notifications + 1
          end,
        },
      }
  end)
  local widget = fixture.widget(path)
  fixture.cursor(widget, path .. "/a.txt")
  await(widget._action:operate("move", { rename = true, name = "b.txt" }))
  fixture.idle(widget)
  t.assert_true(vim.uv.fs_stat(path .. "/a.txt") ~= nil)
  t.assert_eq(nil, vim.uv.fs_stat(path .. "/b.txt"))
  t.assert_eq("LSP destination edits", vim.api.nvim_buf_get_lines(target, 0, -1, false)[1])
  t.assert_eq(0, notifications)
end)

t:test("a late buffer collision preserves contents and rejects writes to the obsolete source path", function()
  local path = assert(vim.uv.fs_realpath(fixture.directory()))
  local source, target = path .. "/a.txt", path .. "/b.txt"
  fixture.write(source)
  local from = vim.fn.bufadd(source)
  vim.fn.bufload(from)
  vim.api.nvim_buf_set_lines(from, 0, -1, false, { "source edits" })
  assert(vim.uv.fs_rename(source, target))
  local to = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_buf_set_name(to, target)
  vim.api.nvim_buf_set_lines(to, 0, -1, false, { "target edits" })
  t:defer(function()
    for _, bufnr in ipairs({ from, to }) do
      if vim.api.nvim_buf_is_valid(bufnr) then
        vim.api.nvim_buf_delete(bufnr, { force = true })
      end
    end
  end)
  local reports = {}
  buffers.sync({
    operation = "move",
    report = function(message)
      reports[#reports + 1] = message
    end,
  }, {
    status = "success",
    source = source,
    target = target,
  })
  t.assert_eq(1, #reports)
  t.assert_eq(target, vim.b[from].filetree_move_target)
  local written, error = pcall(vim.api.nvim_buf_call, from, function()
    vim.cmd.write({ bang = true })
  end)
  t.assert_false(written)
  t.assert_true(tostring(error):find("resolve this buffer's filename", 1, true) ~= nil)
  t.assert_eq(nil, vim.uv.fs_stat(source))
  t.assert_eq("source edits", vim.api.nvim_buf_get_lines(from, 0, -1, false)[1])
  t.assert_eq("target edits", vim.api.nvim_buf_get_lines(to, 0, -1, false)[1])
  local recovered = path .. "/recovered.txt"
  vim.api.nvim_buf_set_name(from, recovered)
  vim.api.nvim_buf_call(from, function()
    vim.cmd.write()
  end)
  t.assert_eq("source edits", vim.fn.readfile(recovered)[1])
  t.assert_eq(nil, vim.b[from].filetree_move_target)
  t.assert_eq(nil, vim.uv.fs_stat(source))
  t.assert_eq("test", vim.fn.readfile(target)[1])
end)

t:run()
