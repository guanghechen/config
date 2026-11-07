require("ark.bootstrap").setup()
local t = require("__test__.support.harness").new()

local S = era.m.notepad
local FLUSH_ON_EXIT = "guanghechen_notepad_flush_on_VimLeavePre"

---@param path                          string
---@param text                          string
---@return nil
local function write(path, text)
  local file = assert(io.open(path, "wb"))
  file:write(text)
  file:close()
end

---@param path                          string
---@return string|nil
local function read(path)
  local file = io.open(path, "rb")
  if file == nil then
    return nil
  end
  local text = file:read("*a")
  file:close()
  return text
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

t:test("a lost or broken index is rebuilt from the note files without writing over them", function()
  t:patch_table(stl.reporter, "warn", function() end)
  t:patch_table(stl.reporter, "error", function() end)
  for _, metadata in ipairs({ false, '{"items": [{"uuid": "a", "name": "Note"}' }) do
    local dirpath = t:tempdir()
    write(vim.fs.joinpath(dirpath, "Note.md"), "precious\n")
    write(vim.fs.joinpath(dirpath, "Other.md"), "other\n")
    if metadata then
      write(vim.fs.joinpath(dirpath, ".__notepad__"), metadata)
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
  local errors = 0
  t:patch_table(stl.reporter, "error", function()
    errors = errors + 1
  end)
  local dirpath = t:tempdir()
  local other = cached_source(dirpath)
  local uuid = other:load(false).active_uuid
  other:update(uuid, { name = "Note", content = "kept" })

  vim.api.nvim_exec_autocmds("VimLeavePre", { group = FLUSH_ON_EXIT })

  t.assert_eq(1, errors, "the failing source is reported")
  t.assert_eq("kept\n", read(vim.fs.joinpath(dirpath, "Note.md")))
end)

t:run()
