require("ark.bootstrap").setup()
local bootstrap = require("__test__.support.bootstrap")
local fs = require("__test__.support.fs")
local t = require("__test__.support.harness").new()

local S = era.m.notepad
local FLUSH_ON_EXIT = "guanghechen_notepad_flush_on_VimLeavePre"

---The bytes of `path`, or nil without the file.
---@param path                          string
---@return string|nil
local function read(path)
  return vim.uv.fs_stat(path) ~= nil and fs.read(path) or nil
end

---@param dirpath                       string
---@return era.m.notepad.state.ISourceConfig
local function config(dirpath)
  return {
    name = "test:" .. dirpath,
    title = "Notes (test)",
    engine = "folder",
    filepath = dirpath,
    default_item_name = function()
      return "Note"
    end,
  }
end

---A folder source over `dirpath` as the notepad state caches it, so quitting flushes it too.
---@param dirpath                       string
---@return era.m.notepad.state.source.Folder
local function cached_source(dirpath)
  -- The cache keeps a source by name for the whole session, so each case names its own.
  local source_config = config(dirpath)
  t:patch_table(S.state.source_config_map, source_config.name, source_config)
  local source = S.state.retrieve_source(source_config.name) ---@type era.m.notepad.state.source.Folder
  t:defer(function()
    -- The cache outlives the case; an unloaded source has nothing left to flush.
    source._flush_debounced:cancel()
    source._state = nil
  end)
  return source
end

---@param source                        era.m.notepad.state.source.Folder
---@return string
local function notes(source)
  local state = source:load(false)
  local listed = {} ---@type string[]
  for _, uuid in ipairs(state.orders) do
    local item = state.items[uuid]
    source:__load_note_content__(item)
    listed[#listed + 1] = item.name .. "=" .. item.content
  end
  return table.concat(listed, " ")
end

t:test("editing a note leaves the file to the debounced flush", function()
  local dirpath = t:tempdir()
  local source = cached_source(dirpath)
  local state = source:load(false)
  local uuid = state.active_uuid
  local filepath = vim.fs.joinpath(dirpath, "Note.md")

  source:update(uuid, { name = "Note", content = "a" })
  source:update(uuid, { name = "Note", content = "ab" })
  t.assert_eq("\n", read(filepath), "edits are not written one by one")

  t.assert_true(source:flush(), "flushed")
  t.assert_eq("ab\n", read(filepath))
end)

t:test("quitting right after a rename keeps the note under its new name", function()
  local dirpath = t:tempdir()
  local source = cached_source(dirpath)
  local uuid = source:load(false).active_uuid
  source:update(uuid, { name = "Note", content = "hello" })
  source:rename(uuid, "Renamed")

  vim.api.nvim_exec_autocmds("VimLeavePre", { group = FLUSH_ON_EXIT })

  t.assert_eq("Renamed=hello", notes(S.FolderSource.new(config(dirpath))))
end)

t:test("a rename whose file cannot move keeps the note under its old name", function()
  local reports = bootstrap.with_reporter(t)
  local dirpath = t:tempdir()
  local source = cached_source(dirpath)
  local uuid = source:load(false).active_uuid
  source:update(uuid, { name = "Note", content = "hello" })
  t.assert_true(source:flush(), "flushed")
  -- A read-only folder refuses to move the note file.
  vim.uv.fs_chmod(dirpath, tonumber("555", 8))
  t:defer(function()
    vim.uv.fs_chmod(dirpath, tonumber("755", 8))
  end)

  t.assert_false(source:rename(uuid, "Renamed"), "rename refused")
  t.assert_false(source:update(uuid, { name = "Renamed", content = "hello" }), "renaming update refused")

  t.assert_eq("Note=hello", notes(source))
  t.assert_same({ "Failed to rename note file", "Failed to rename note file" }, bootstrap.messages(reports.error))
end)

t:test("a note whose file cannot be deleted stays listed", function()
  local reports = bootstrap.with_reporter(t)
  local dirpath = t:tempdir()
  local source = cached_source(dirpath)
  source:load(false)
  local other = source:create("Other", "kept")
  t.assert_true(source:flush(), "flushed")
  local listed = notes(source)
  -- A read-only folder refuses to delete the note file.
  vim.uv.fs_chmod(dirpath, tonumber("555", 8))
  t:defer(function()
    vim.uv.fs_chmod(dirpath, tonumber("755", 8))
  end)

  t.assert_false(source:remove(other.uuid), "removal refused")
  t.assert_eq(listed, notes(source), "still listed")
  t.assert_eq("kept\n", read(vim.fs.joinpath(dirpath, "Other.md")), "the file stays")
  t.assert_same({ "Failed to delete note file" }, bootstrap.messages(reports.error))
end)

t:test("a lost or broken index is rebuilt from the note files without writing over them", function()
  bootstrap.with_reporter(t)
  for _, metadata in ipairs({ false, '{"items": [{"uuid": "a", "name": "Note"}' }) do
    local dirpath = t:tempdir()
    fs.write(vim.fs.joinpath(dirpath, "Note.md"), "precious\n")
    fs.write(vim.fs.joinpath(dirpath, "Other.md"), "other\n")
    if metadata then
      fs.write(vim.fs.joinpath(dirpath, ".__notepad__"), metadata)
    end
    local source = S.FolderSource.new(config(dirpath))

    t.assert_eq("Note=precious Other=other", notes(source))
    t.assert_eq("precious\n", read(vim.fs.joinpath(dirpath, "Note.md")), "the default note keeps its file")
    t.assert_true(source:flush(), "flushed")
    t.assert_eq("Note=precious Other=other", notes(S.FolderSource.new(config(dirpath))), "the rebuilt index persists")
  end
end)

t:test("quitting after only reading writes nothing, and a content edit leaves the index alone", function()
  local dirpath = t:tempdir()
  local source = cached_source(dirpath)
  local uuid = source:load(false).active_uuid
  t.assert_true(source:flush(), "the new note is saved")
  local metadata = vim.fs.joinpath(dirpath, ".__notepad__")
  local note = vim.fs.joinpath(dirpath, "Note.md")
  ---@param path                        string
  ---@return string
  local function identity(path)
    local stat = assert(vim.uv.fs_stat(path))
    return string.format("%d:%d.%09d", stat.ino, stat.mtime.sec, stat.mtime.nsec)
  end
  local written = identity(metadata) .. " " .. identity(note)

  source:retrieve(uuid)
  vim.api.nvim_exec_autocmds("VimLeavePre", { group = FLUSH_ON_EXIT })
  t.assert_eq(written, identity(metadata) .. " " .. identity(note), "reading writes nothing")

  source:update(uuid, { name = "Note", content = "edited" })
  vim.api.nvim_exec_autocmds("VimLeavePre", { group = FLUSH_ON_EXIT })
  t.assert_eq(written:match("^%S+"), identity(metadata), "a content edit leaves the index alone")
  t.assert_eq("edited\n", read(note))
end)

t:test("quitting flushes every source even when one of them fails", function()
  local failing = cached_source(t:tempdir())
  failing:load(false)
  t:patch_table(failing, "flush", function()
    error("disk gone")
  end)
  local reports = bootstrap.with_reporter(t)
  local dirpath = t:tempdir()
  local other = cached_source(dirpath)
  local uuid = other:load(false).active_uuid
  other:update(uuid, { name = "Note", content = "kept" })

  vim.api.nvim_exec_autocmds("VimLeavePre", { group = FLUSH_ON_EXIT })

  t.assert_eq(1, #reports.error, "the failing source is reported")
  t.assert_eq("kept\n", read(vim.fs.joinpath(dirpath, "Note.md")))
end)

---A folder source over a new directory whose notes are `contents`, by name, in order.
---@param contents                      {[1]: string, [2]: string}[]
---@return era.m.notepad.state.source.Folder
---@return string dirpath
local function source_with(contents)
  local dirpath = t:tempdir()
  local source = S.FolderSource.new(config(dirpath))
  local first = source:load(false).active_uuid
  for index, entry in ipairs(contents) do
    local item = index == 1 and source:retrieve(first) or source:create(entry[1])
    source:update(item.uuid, { name = entry[1], content = entry[2] })
  end
  t.assert_true(source:flush(), "flushed")
  return source, dirpath
end

t:test("names that share a file reuse its note instead of emptying it", function()
  local source, dirpath = source_with({ { "a/b", "x" }, { "Todo", "important" } })

  t.assert_eq("a/b", source:create("a_b").name, "a sanitized name finds the note of its file")
  -- Only a filesystem that ignores case stores `todo` in `Todo.md`.
  local insensitive = vim.uv.fs_stat(vim.fs.joinpath(dirpath, "todo.md")) ~= nil
  t.assert_eq(insensitive and "Todo" or "todo", source:create("todo").name)
  t.assert_true(source:flush(), "flushed")

  t.assert_eq("x\n", read(vim.fs.joinpath(dirpath, "a_b.md")))
  t.assert_eq("important\n", read(vim.fs.joinpath(dirpath, "Todo.md")))
end)

t:test("renaming onto the file of another note is rejected, while changing only the case keeps the note", function()
  bootstrap.with_reporter(t)
  local source, dirpath = source_with({ { "a/b", "x" }, { "Other", "other" } })
  local other = source:load(false).name_to_uuid["Other"]

  t.assert_eq(false, source:rename(other, "a_b"), "a_b is the file of a/b")
  t.assert_true(source:rename(other, "OTHER"), "the same note under another case")
  t.assert_true(source:flush(), "flushed")

  t.assert_eq("a/b=x OTHER=other", notes(S.FolderSource.new(config(dirpath))))
end)

t:test("a note file missing from the index is adopted with its text", function()
  local source, dirpath = source_with({ { "Note", "first" } })
  fs.write(vim.fs.joinpath(dirpath, "Extra.md"), "kept\n")

  source:create("Extra")
  t.assert_true(source:flush(), "flushed")

  t.assert_eq("kept\n", read(vim.fs.joinpath(dirpath, "Extra.md")))
  t.assert_eq("Note=first Extra=kept", notes(S.FolderSource.new(config(dirpath))))
end)

t:run()
