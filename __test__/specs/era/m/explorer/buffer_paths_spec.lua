---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.specs.era.m.explorer.buffer_paths" ---@type string

local fixture = require("__test__.support.explorer").new("era.m.explorer.buffer_paths")
local t, await = fixture.t, fixture.await
local buffers = require("era.m.explorer.buffers")

---@return string
local function directory()
  local path
  if vim.env.YOZ_PATH_TEST_VOLUME then
    path = vim.env.YOZ_PATH_TEST_VOLUME .. "/explorer-buffer-paths-" .. vim.uv.hrtime()
    assert(vim.uv.fs_mkdir(path, 448))
    t:defer(function()
      vim.fn.delete(path, "rf")
    end)
  else
    path = fixture.directory()
  end
  path = assert(vim.uv.fs_realpath(path))
  t:defer(function()
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_get_name(bufnr):sub(1, #path + 1) == path .. "/" then
        vim.api.nvim_buf_delete(bufnr, { force = true })
      end
    end
  end)
  return path
end

---@param path                          string
---@param left                          string
---@param right                         string
---@return boolean
local function filesystem_equivalent(path, left, right)
  fixture.write(path .. "/" .. left)
  local equivalent = vim.uv.fs_stat(path .. "/" .. right) ~= nil
  assert(vim.uv.fs_unlink(path .. "/" .. left))
  return equivalent
end

---@param name                          string
---@param contents                      string
---@return integer
local function edited_buffer(name, contents)
  local bufnr = vim.fn.bufadd(name)
  vim.fn.bufload(bufnr)
  vim.api.nvim_set_option_value("buflisted", true, { buf = bufnr })
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { contents })
  return bufnr
end

---@param source                        string
---@param target                        string
---@return string[]
local function synchronize(source, target)
  local reports = {}
  buffers.sync({
    operation = "move",
    report = function(message)
      reports[#reports + 1] = message
    end,
  }, { status = "success", source = source, target = target })
  return reports
end

for _, case in ipairs({
  { label = "case", name = "TARGET", alias = "target", old = "OLD", old_alias = "old" },
  { label = "Unicode", name = "café", alias = "café", old = "café-old", old_alias = "café-old" },
  { label = "supplementary case", name = "𐐀", alias = "𐐨", old = "𐐀-old", old_alias = "𐐨-old" },
  { label = "Cyrillic case fold", name = "ᲀ", alias = "в", old = "ᲀ-old", old_alias = "в-old" },
  {
    label = "supplementary normalization",
    name = "𝅗𝅥",
    alias = "𝅗𝅥",
    old = "𝅗𝅥-old",
    old_alias = "𝅗𝅥-old",
  },
}) do
  for _, is_directory in ipairs({ false, true }) do
    t:test(
      case.label .. (is_directory and " directory" or " file") .. " targets protect equivalent unopened buffers",
      function()
        local path = directory()
        local equivalent = filesystem_equivalent(path, case.name, case.alias)
        local source, target, name = path .. "/source", path .. "/" .. case.name, path .. "/" .. case.alias
        if is_directory then
          assert(vim.uv.fs_mkdir(source, 448))
          fixture.write(source .. "/notes.txt")
          name = name .. "/notes.txt"
        else
          fixture.write(source)
        end
        local bufnr = edited_buffer(name, "destination edits")
        local widget = fixture.widget(path)
        fixture.cursor(widget, source)
        await(widget._action:operate("move", { rename = true, name = case.name }))
        fixture.idle(widget)
        t.assert_eq(equivalent, vim.uv.fs_stat(source) ~= nil)
        t.assert_eq(not equivalent, vim.uv.fs_stat(target) ~= nil)
        t.assert_eq(equivalent and 0 or 1, widget._session._counts.success)
        t.assert_eq(equivalent and 1 or 0, widget._session._counts.skipped)
        t.assert_eq("destination edits", vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)[1])
        t.assert_true(vim.api.nvim_get_option_value("modified", { buf = bufnr }))
      end
    )
  end

  t:test(case.label .. " source matching preserves descendant suffix and undo history", function()
    local path = directory()
    local equivalent = filesystem_equivalent(path, case.name, case.alias)
    local source, target = path .. "/" .. case.name, path .. "/renamed"
    assert(vim.uv.fs_mkdir(source, 448))
    fixture.write(source .. "/notes.txt")
    local original = path .. "/" .. case.alias .. "/notes.txt"
    local bufnr = edited_buffer(original, "source edits")
    local undo = vim.api.nvim_buf_call(bufnr, vim.fn.undotree)
    assert(vim.uv.fs_rename(source, target))
    t.assert_eq(0, #synchronize(source, target))
    t.assert_eq(equivalent and target .. "/notes.txt" or original, vim.api.nvim_buf_get_name(bufnr))
    t.assert_eq("source edits", vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)[1])
    t.assert_true(vim.api.nvim_get_option_value("modified", { buf = bufnr }))
    t.assert_eq(undo.seq_cur, vim.api.nvim_buf_call(bufnr, vim.fn.undotree).seq_cur)
    t.assert_eq("test", vim.fn.readfile(target .. "/notes.txt")[1])
  end)

  t:test(case.label .. " late collisions protect alternate source spellings and permit explicit recovery", function()
    local path = directory()
    local equivalent = filesystem_equivalent(path, case.name, case.alias)
    if not equivalent then
      -- Neovim's global default on macOS otherwise refuses distinct case-sensitive filenames.
      local ignorecase = vim.o.fileignorecase
      t:defer(function()
        vim.o.fileignorecase = ignorecase
      end)
      vim.o.fileignorecase = false
    end
    local source, target = path .. "/" .. case.old, path .. "/" .. case.name
    fixture.write(source)
    local from = edited_buffer(source, "source edits")
    assert(vim.uv.fs_rename(source, target))
    local to = edited_buffer(path .. "/" .. case.alias, "target edits")
    local reports = synchronize(source, target)
    t.assert_eq(equivalent and 1 or 0, #reports)
    t.assert_eq(equivalent and target or nil, vim.b[from].filetree_move_target)
    t.assert_eq("source edits", vim.api.nvim_buf_get_lines(from, 0, -1, false)[1])
    t.assert_eq("target edits", vim.api.nvim_buf_get_lines(to, 0, -1, false)[1])
    if not equivalent then
      t.assert_eq(target, vim.api.nvim_buf_get_name(from))
      return
    end

    local old_alias = path .. "/" .. case.old_alias
    local written = pcall(vim.api.nvim_buf_call, from, function()
      vim.cmd.write({ args = { old_alias }, bang = true })
    end)
    t.assert_false(written, "explicit writes to an old-path alias must remain protected")
    vim.api.nvim_buf_set_name(from, old_alias)
    written = pcall(vim.api.nvim_buf_call, from, function()
      vim.cmd.write({ bang = true })
    end)
    t.assert_false(written, "changing only the old path spelling must not clear protection")
    t.assert_eq(nil, vim.uv.fs_stat(source))
    t.assert_eq(target, vim.b[from].filetree_move_target)

    local recovery = path .. "/recovered.txt"
    vim.api.nvim_buf_call(from, function()
      vim.cmd.write({ args = { recovery } })
    end)
    t.assert_eq("source edits", vim.fn.readfile(recovery)[1])
    t.assert_eq(target, vim.b[from].filetree_move_target, "writing a copy keeps the original name protected")
    local renamed = path .. "/resolved.txt"
    vim.api.nvim_buf_set_name(from, renamed)
    vim.api.nvim_buf_call(from, function()
      vim.cmd.write()
    end)
    t.assert_eq(nil, vim.b[from].filetree_move_target)
    t.assert_eq("source edits", vim.fn.readfile(renamed)[1])
    t.assert_eq(nil, vim.uv.fs_stat(source))
    t.assert_eq("test", vim.fn.readfile(target)[1])
  end)
end

for _, dangling in ipairs({ false, true }) do
  t:test(
    (dangling and "dangling" or "existing") .. " parent aliases protect buffers under missing target directories",
    function()
      local path = directory()
      assert(vim.uv.fs_mkdir(path .. "/real", 448))
      assert(vim.uv.fs_mkdir(path .. "/real/old", 448))
      fixture.write(path .. "/real/old/notes.txt")
      assert(vim.uv.fs_symlink(dangling and "real/new" or "real", path .. "/alias", { dir = true }))
      local name = path .. (dangling and "/alias/notes.txt" or "/alias/new/notes.txt")
      local bufnr = edited_buffer(name, "destination edits")
      t.assert_eq(name, vim.api.nvim_buf_get_name(bufnr), "Neovim retains aliases when the immediate parent is missing")
      local widget = fixture.widget(path .. "/real")
      fixture.cursor(widget, path .. "/real/old")
      await(widget._action:operate("move", { rename = true, name = "new" }))
      fixture.idle(widget)
      t.assert_eq(0, widget._session._counts.success)
      t.assert_eq(1, widget._session._counts.skipped)
      t.assert_true(vim.uv.fs_stat(path .. "/real/old/notes.txt") ~= nil)
      t.assert_eq(nil, vim.uv.fs_stat(path .. "/real/new"))
      t.assert_eq("destination edits", vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)[1])
    end
  )
end

t:test("overwriting a directory symlink protects its missing descendant buffer", function()
  local path = directory()
  local source, target = path .. "/source", path .. "/target"
  assert(vim.uv.fs_mkdir(path .. "/external", 448))
  assert(vim.uv.fs_symlink("external", target, { dir = true }))
  fixture.write(source)
  local name = target .. "/missing/notes.txt"
  local bufnr = edited_buffer(name, "destination edits")
  t.assert_eq(name, vim.api.nvim_buf_get_name(bufnr))
  t:patch_table(vim.ui, "select", function(items, _, done)
    done(items[2], 2)
  end)
  local widget = fixture.widget(path)
  fixture.cursor(widget, source)
  await(widget._action:operate("move", { rename = true, name = "target" }))
  fixture.idle(widget)
  t.assert_eq(0, widget._session._counts.success)
  t.assert_eq(1, widget._session._counts.skipped)
  t.assert_eq("external", vim.uv.fs_readlink(target))
  t.assert_true(vim.uv.fs_stat(source) ~= nil)
  t.assert_eq("destination edits", vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)[1])
  t.assert_true(vim.api.nvim_get_option_value("modified", { buf = bufnr }))
  t.assert_eq(nil, vim.b[bufnr].filetree_move_target)
end)

t:test("an aliased parent keeps descendant buffer dependencies in target checks", function()
  local path = directory()
  assert(vim.uv.fs_mkdir(path .. "/work", 448))
  assert(vim.uv.fs_mkdir(path .. "/aliases", 448))
  assert(vim.uv.fs_mkdir(path .. "/external", 448))
  assert(vim.uv.fs_symlink("../work", path .. "/aliases/mount", { dir = true }))
  local source, target = path .. "/work/source", path .. "/work/target"
  fixture.write(source)
  assert(vim.uv.fs_symlink(path .. "/external", target, { dir = true }))
  local name = path .. "/aliases/mount/target/missing/notes.txt"
  local bufnr = edited_buffer(name, "destination edits")
  t.assert_eq(name, vim.api.nvim_buf_get_name(bufnr))
  t:patch_table(vim.ui, "select", function(items, _, done)
    done(items[2], 2)
  end)
  local widget = fixture.widget(path .. "/work")
  fixture.cursor(widget, source)
  await(widget._action:operate("move", { rename = true, name = "target" }))
  fixture.idle(widget)
  t.assert_eq(0, widget._session._counts.success)
  t.assert_eq(1, widget._session._counts.skipped)
  t.assert_eq(path .. "/external", vim.uv.fs_readlink(target))
  t.assert_true(vim.uv.fs_stat(source) ~= nil)
  t.assert_eq("destination edits", vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)[1])
  t.assert_true(vim.api.nvim_get_option_value("modified", { buf = bufnr }))
end)

t:test("a parent replaced by a file still permits an independent copy and explicit buffer recovery", function()
  local path = directory()
  local source, target = path .. "/source", path .. "/target"
  assert(vim.uv.fs_mkdir(path .. "/external", 448))
  assert(vim.uv.fs_symlink("external", target, { dir = true }))
  fixture.write(source)
  local name = target .. "/missing/notes.txt"
  local bufnr = edited_buffer(name, "destination edits")
  local undo = vim.api.nvim_buf_call(bufnr, vim.fn.undotree)
  assert(vim.uv.fs_unlink(target))
  assert(vim.uv.fs_rename(source, target))
  t.assert_eq(1, #synchronize(source, target))
  t.assert_eq(target, vim.b[bufnr].filetree_move_target)
  t.assert_eq(name, vim.api.nvim_buf_get_name(bufnr))
  local written = pcall(vim.api.nvim_buf_call, bufnr, function()
    vim.cmd.write({ bang = true })
  end)
  t.assert_false(written, "the obsolete filename remains protected")
  t.assert_eq(undo.seq_cur, vim.api.nvim_buf_call(bufnr, vim.fn.undotree).seq_cur)
  local copy = path .. "/copy.txt"
  vim.api.nvim_buf_call(bufnr, function()
    vim.cmd.write({ args = { copy } })
  end)
  t.assert_eq("destination edits", vim.fn.readfile(copy)[1])
  t.assert_eq(target, vim.b[bufnr].filetree_move_target, "a copy does not clear protection of the old name")
  local recovered = path .. "/recovered.txt"
  vim.api.nvim_buf_set_name(bufnr, recovered)
  vim.api.nvim_buf_call(bufnr, function()
    vim.cmd.write()
  end)
  t.assert_eq("destination edits", vim.fn.readfile(recovered)[1])
  t.assert_eq(nil, vim.b[bufnr].filetree_move_target)
  t.assert_eq("test", vim.fn.readfile(target)[1])
end)

t:test("a moved directory synchronizes missing descendants through an existing parent alias", function()
  local path = directory()
  assert(vim.uv.fs_mkdir(path .. "/real", 448))
  assert(vim.uv.fs_mkdir(path .. "/real/old", 448))
  fixture.write(path .. "/real/old/sentinel")
  assert(vim.uv.fs_symlink("real", path .. "/alias", { dir = true }))
  local bufnr = edited_buffer(path .. "/alias/old/missing/notes.txt", "source edits")
  local undo = vim.api.nvim_buf_call(bufnr, vim.fn.undotree)
  local widget = fixture.widget(path .. "/real")
  fixture.cursor(widget, path .. "/real/old")
  await(widget._action:operate("move", { rename = true, name = "new" }))
  fixture.idle(widget)
  t.assert_eq(1, widget._session._counts.success)
  t.assert_eq(path .. "/real/new/missing/notes.txt", vim.api.nvim_buf_get_name(bufnr))
  t.assert_eq(nil, vim.b[bufnr].filetree_move_target)
  t.assert_eq("source edits", vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)[1])
  t.assert_eq(undo.seq_cur, vim.api.nvim_buf_call(bufnr, vim.fn.undotree).seq_cur)
end)

for _, fail_rename in ipairs({ false, true }) do
  t:test(
    "a source parent alias that becomes dangling "
      .. (fail_rename and "permits explicit recovery" or "still synchronizes"),
    function()
      local path = directory()
      assert(vim.uv.fs_mkdir(path .. "/old", 448))
      fixture.write(path .. "/old/sentinel")
      assert(vim.uv.fs_symlink("old", path .. "/alias", { dir = true }))
      local name = path .. "/alias/missing/notes.txt"
      local bufnr = edited_buffer(name, "source edits")
      local target = path .. "/new/missing/notes.txt"
      if fail_rename then
        t:patch_table(era.m.lsp.event, "rename_buf", function()
          error("injected late rename failure")
        end)
      end
      local widget = fixture.widget(path)
      fixture.cursor(widget, path .. "/old")
      await(widget._action:operate("move", { rename = true, name = "new" }))
      fixture.idle(widget)
      t.assert_eq(1, widget._session._counts.success)
      t.assert_eq("source edits", vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)[1])
      if not fail_rename then
        t.assert_eq(target, vim.api.nvim_buf_get_name(bufnr))
        t.assert_eq(nil, vim.b[bufnr].filetree_move_target)
        return
      end
      t.assert_eq(name, vim.api.nvim_buf_get_name(bufnr))
      t.assert_eq(target, vim.b[bufnr].filetree_move_target)
      local written, reason = pcall(vim.api.nvim_buf_call, bufnr, function()
        vim.cmd.write({ bang = true })
      end)
      t.assert_false(written)
      t.assert_true(tostring(reason):find("resolve this buffer's filename", 1, true) ~= nil)
      local copy = path .. "/copy.txt"
      vim.api.nvim_buf_call(bufnr, function()
        vim.cmd.write({ args = { copy } })
      end)
      t.assert_eq("source edits", vim.fn.readfile(copy)[1])
      t.assert_eq(target, vim.b[bufnr].filetree_move_target)
      local recovered = path .. "/recovered.txt"
      vim.api.nvim_buf_set_name(bufnr, recovered)
      vim.api.nvim_buf_call(bufnr, function()
        vim.cmd.write()
      end)
      t.assert_eq("source edits", vim.fn.readfile(recovered)[1])
      t.assert_eq(nil, vim.b[bufnr].filetree_move_target)
      t.assert_eq(nil, vim.uv.fs_stat(path .. "/old"))
    end
  )
end

t:test("case-only rename synchronizes its own buffer without a false target collision", function()
  local path = directory()
  local source, target = path .. "/lower.txt", path .. "/LOWER.txt"
  fixture.write(source)
  local bufnr = edited_buffer(source, "source edits")
  local widget = fixture.widget(path)
  fixture.cursor(widget, source)
  await(widget._action:operate("move", { rename = true, name = "LOWER.txt" }))
  fixture.idle(widget)
  t.assert_eq(1, widget._session._counts.success)
  t.assert_eq(target, vim.api.nvim_buf_get_name(bufnr))
  t.assert_eq(nil, vim.b[bufnr].filetree_move_target)
  t.assert_eq("source edits", vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)[1])
  t.assert_true(vim.api.nvim_get_option_value("modified", { buf = bufnr }))
  t.assert_eq("test", vim.fn.readfile(target)[1])
end)

t:test("stricter editor filename rules preserve both buffers when synchronization is refused", function()
  local path = directory()
  local ignorecase = vim.o.fileignorecase
  t:defer(function()
    vim.o.fileignorecase = ignorecase
  end)
  vim.o.fileignorecase = true
  local source, target = path .. "/source", path .. "/TARGET"
  fixture.write(source)
  local from = edited_buffer(source, "source edits")
  assert(vim.uv.fs_rename(source, target))
  local to = edited_buffer(path .. "/target", "target edits")
  t.assert_eq(1, #synchronize(source, target))
  t.assert_eq(target, vim.b[from].filetree_move_target)
  t.assert_eq("source edits", vim.api.nvim_buf_get_lines(from, 0, -1, false)[1])
  t.assert_eq("target edits", vim.api.nvim_buf_get_lines(to, 0, -1, false)[1])
end)

t:test("path-query failure refuses a move before IO", function()
  local path = directory()
  local source, target = path .. "/source", path .. "/target"
  fixture.write(source)
  edited_buffer(target, "destination edits")
  local compare = yoz.fs.path_suffix
  t:patch_table(yoz.fs, "path_suffix", function(base, name)
    if base == target and name == target then
      return nil, "injected filename-rule lookup failure"
    end
    return compare(base, name)
  end)
  local widget = fixture.widget(path)
  fixture.cursor(widget, source)
  await(widget._action:operate("move", { rename = true, name = "target" }))
  fixture.idle(widget)
  t.assert_eq(0, widget._session._counts.success)
  t.assert_eq(1, widget._session._counts.skipped)
  t.assert_true(vim.uv.fs_stat(source) ~= nil)
  t.assert_eq(nil, vim.uv.fs_stat(target))
end)

t:test("path-query failure after IO preserves and protects the unresolved buffer", function()
  local path = directory()
  local source, target = path .. "/source", path .. "/target"
  fixture.write(source)
  local bufnr = edited_buffer(source, "source edits")
  assert(vim.uv.fs_rename(source, target))
  local compare = yoz.fs.path_suffix
  t:patch_table(yoz.fs, "path_suffix", function(base, name)
    if base == source and name == source then
      return nil, "injected filename-rule lookup failure"
    end
    return compare(base, name)
  end)
  t.assert_eq(1, #synchronize(source, target))
  t.assert_eq(source, vim.api.nvim_buf_get_name(bufnr))
  t.assert_eq(target, vim.b[bufnr].filetree_move_target)
  local written, reason = pcall(vim.api.nvim_buf_call, bufnr, function()
    vim.cmd.write({ bang = true })
  end)
  t.assert_false(written)
  t.assert_true(tostring(reason):find("filename-rule lookup failure", 1, true) ~= nil)
  t.assert_eq(nil, vim.uv.fs_stat(source))
  t.assert_eq("source edits", vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)[1])
  t.assert_true(vim.api.nvim_get_option_value("modified", { buf = bufnr }))
end)

t:test("hard-link identity does not move an unrelated buffer namespace", function()
  local path = directory()
  local source, target, alias = path .. "/source", path .. "/target", path .. "/hard-link"
  fixture.write(source)
  assert(vim.uv.fs_link(source, alias))
  local bufnr = edited_buffer(alias, "alias edits")
  assert(vim.uv.fs_rename(source, target))
  t.assert_eq(0, #synchronize(source, target))
  t.assert_eq(alias, vim.api.nvim_buf_get_name(bufnr))
  t.assert_eq("alias edits", vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)[1])
end)

t:run()
