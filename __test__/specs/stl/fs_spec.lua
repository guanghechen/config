local bootstrap = require("__test__.support.bootstrap")
local harness = require("__test__.support.harness")

local t = harness.new()
bootstrap.with_native(t)
bootstrap.with_global(t, "stl", { env = require("stl.env") })

local Fs = require("stl.fs")

-- Writes exact bytes; `writefile` would end every line with LF.
---@param text                          string
---@return string
local function fixture(text)
  local filepath = vim.fs.joinpath(t:tempdir(), "lines.txt")
  local file = assert(io.open(filepath, "wb"))
  file:write(text)
  file:close()
  return filepath
end

---@param filepath                      string
---@param text                          string
---@return nil
local function put(filepath, text)
  local file = assert(io.open(filepath, "wb"))
  file:write(text)
  file:close()
end

---@param filepath                      string
---@return string
local function read(filepath)
  local file = assert(io.open(filepath, "rb"))
  local content = file:read("*a")
  file:close()
  return content
end

---@param dirpath                       string
---@return string[]
local function entries(dirpath)
  local names = {} ---@type string[]
  for name in vim.fs.dir(dirpath) do
    names[#names + 1] = name
  end
  table.sort(names)
  return names
end

t:test("read_file_as_lines: drops only the carriage return of a CRLF line break", function()
  local filepath = fixture("a\r\nb\nc\rd\r\n\r\n\26tail")
  t.assert_same({ "a", "b", "c\rd", "", "\26tail" }, Fs.read_file_as_lines({ filepath = filepath }), "lines")
end)

t:test("read_file_as_lines: stops at max_lines", function()
  local filepath = fixture("a\r\nb\r\nc\r\n")
  t.assert_same({ "a", "b" }, Fs.read_file_as_lines({ filepath = filepath, max_lines = 2 }), "lines")
end)

t:test("read_file_as_lines: drops the byte order mark that starts the file, not one further on", function()
  local filepath = fixture("\239\187\191a\r\n\239\187\191b\nc\239\187\191d\n")
  t.assert_same({ "a", "\239\187\191b", "c\239\187\191d" }, Fs.read_file_as_lines({ filepath = filepath }), "lines")
end)

t:test("write_file: replaces the content and leaves no temporary file", function()
  local dirpath = t:tempdir()
  local filepath = vim.fs.joinpath(dirpath, "state.json")

  t.assert_true(Fs.write_file(filepath, "first"), "first write")
  t.assert_true(Fs.write_file(filepath, "second"), "second write")

  t.assert_eq("second", read(filepath), "content")
  t.assert_same({ "state.json" }, entries(dirpath), "directory entries")
end)

t:test("write_file: a failed write keeps the previous content", function()
  local dirpath = t:tempdir()
  local filepath = vim.fs.joinpath(dirpath, "state.json")
  put(filepath, "previous")
  local reports = bootstrap.with_reporter(t)
  t:patch_table(vim.uv, "fs_write", function()
    return nil, "ENOSPC: no space left on device"
  end)

  local ok, err = Fs.write_file(filepath, "next")

  t.assert_false(ok, "result")
  t.assert_eq("ENOSPC: no space left on device", err, "error")
  t.assert_eq("previous", read(filepath), "content")
  t.assert_same({ "state.json" }, entries(dirpath), "directory entries")
  t.assert_eq(1, #reports.error, "reported")
end)

t:test("write_file: a failed rename keeps the previous content", function()
  local dirpath = t:tempdir()
  local filepath = vim.fs.joinpath(dirpath, "state.json")
  put(filepath, "previous")
  local reports = bootstrap.with_reporter(t)
  t:patch_table(vim.uv, "fs_rename", function()
    return nil, "EXDEV: cross-device link not permitted"
  end)

  t.assert_false(Fs.write_file(filepath, "next"), "result")
  t.assert_eq("previous", read(filepath), "content")
  t.assert_same({ "state.json" }, entries(dirpath), "directory entries")
  t.assert_eq(1, #reports.error, "reported")
end)

t:test("write_file: leaves a read-only file alone", function()
  local filepath = vim.fs.joinpath(t:tempdir(), "state.json")
  put(filepath, "previous")
  assert(vim.uv.fs_chmod(filepath, tonumber("444", 8)))
  local reports = bootstrap.with_reporter(t)

  t.assert_false(Fs.write_file(filepath, "next"), "result")
  t.assert_eq("previous", read(filepath), "content")
  t.assert_eq(1, #reports.error, "reported")
end)

t:test("write_file: keeps the permissions of the file it replaces", function()
  local filepath = vim.fs.joinpath(t:tempdir(), "state.json")
  put(filepath, "previous")
  assert(vim.uv.fs_chmod(filepath, tonumber("600", 8)))

  Fs.write_file(filepath, "next")

  t.assert_eq(tonumber("600", 8), assert(vim.uv.fs_stat(filepath)).mode % 512, "permissions")
end)

t:test("write_file: writes through a symlink to the file it links to", function()
  local dirpath = t:tempdir()
  local target = vim.fs.joinpath(dirpath, "target.json")
  local link = vim.fs.joinpath(dirpath, "link.json")
  put(target, "previous")
  assert(vim.uv.fs_symlink(target, link))

  Fs.write_file(link, "next")

  t.assert_eq("link", assert(vim.uv.fs_lstat(link)).type, "link kept")
  t.assert_eq("next", read(target), "linked file")
end)

t:test("write_json: reports data that cannot be encoded as a failed write", function()
  local filepath = vim.fs.joinpath(t:tempdir(), "state.json")

  t.assert_false(Fs.write_json(filepath, { callback = function() end }, true), "result")
  t.assert_nil(vim.uv.fs_stat(filepath), "no file")
end)

t:test("watch_file: still reports changes after the file is replaced", function()
  local dirpath = t:tempdir()
  local filepath = vim.fs.joinpath(dirpath, "editor.json")
  put(filepath, "0")
  local events = 0 ---@type integer
  local unwatch = Fs.watch_file({
    filepath = filepath,
    on_event = function()
      events = events + 1
    end,
  })
  ---@diagnostic disable-next-line: invisible
  t:defer(unwatch)
  -- FSEvents starts its stream on another thread, after the watch returns, and misses the changes before that: write
  -- until the watch reports one.
  t.wait_until(function()
    put(filepath, "0")
    return events > 0
  end, 3000, "the watch reports changes")

  -- Replaced the way an atomic writer does it, a sibling file renamed over it, twice.
  for round = 1, 2 do
    local seen = events ---@type integer
    local sibling = vim.fs.joinpath(dirpath, "editor.json.tmp")
    put(sibling, tostring(round))
    assert(vim.uv.fs_rename(sibling, filepath))
    t.wait_until(function()
      return events > seen
    end, 3000, "event after replacement " .. round)
  end
end)

t:run()
