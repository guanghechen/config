--- Timeout: 120000

local encoding_fixture = require("__test__.fixtures.era.m.git.encoding")
local fs = require("__test__.support.fs")
local git = require("__test__.support.git")
local git_buffer = require("__test__.support.git_buffer")
local harness = require("__test__.support.harness")

local t = harness.new()
local writes = git_buffer.index_writes(t)
local staging = writes.staging
local make_repo, committed_repo = writes.make_repo, writes.committed_repo
local index_bytes, index_object, index_snapshot = writes.index_bytes, writes.index_object, writes.index_snapshot
local stage, unstage = writes.stage, writes.unstage

t:test("stage: latin1 content is encoded before hashing", function()
  local repo = committed_repo(assert(vim.iconv("caf\195\169\nx\n", "utf-8", "latin1")))

  local document = staging.from_text("CAF\195\137\nx\n", { encoding = "latin1" })
  t.assert_true(stage(repo, document, { 1, 1 }, index_snapshot(repo, "f.txt", "latin1")).ok, "staged")
  t.assert_eq(assert(vim.iconv("CAF\195\137\nx\n", "utf-8", "latin1")), index_bytes(repo, "f.txt"), "latin1 bytes")
end)

for _, format in ipairs(encoding_fixture.formats) do
  t:test(format.name .. ": unsaved partial stage/unstage matches Neovim file bytes", function()
    for _, bomb in ipairs({ false, true }) do
      for _, fileformat in ipairs({ "unix", "dos" }) do
        for _, eof in ipairs({ "", "\n" }) do
          local prefix = bomb and "\239\187\191" or ""
          local base_text = prefix .. "café中\nmiddle\nlast" .. eof
          local base, bufnr = encoding_fixture.write(t, base_text, format.name, bomb, fileformat)
          local repo = committed_repo(base)
          local changed = prefix .. "CAFÉ中" .. (format.astral and "🙂" or "")
          vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { changed, "middle", "LAST" })
          local document = staging.from_buffer(bufnr)
          t.assert_eq(format.name, document.encoding, "buffer canonical name")
          local expected = encoding_fixture.write(t, changed .. "\nmiddle\nlast" .. eof, format.name, bomb, fileformat)
          local staged = stage(repo, document, { 1, 1 })
          t.assert_true(staged.ok, tostring(staged.err))
          t.assert_eq(
            encoding_fixture.hex(expected),
            encoding_fixture.hex(index_bytes(repo, "f.txt")),
            "selected bytes"
          )
          local unstaged = unstage(repo, { 1, 1 }, index_snapshot(repo, "f.txt", format.name))
          t.assert_true(unstaged.ok, tostring(unstaged.err))
          t.assert_eq(encoding_fixture.hex(base), encoding_fixture.hex(index_bytes(repo, "f.txt")), "restored bytes")
          t.assert_eq(document.text, staging.from_buffer(bufnr).text, "unsaved buffer unchanged")
          t.assert_eq(base, fs.read(repo .. "/f.txt"), "worktree unchanged")
        end
      end
    end
  end)
end

t:test("UTF-16BE alias stages actual BE bytes, including an astral character", function()
  local base = "\254\255\0o\0n\0e\0\n\0t\0w\0o"
  local repo = committed_repo(base)
  local document = staging.from_text("ONE🙂\ntwo", { encoding = "utf-16be", bomb = true })
  local staged = stage(repo, document, { 1, 1 }, index_snapshot(repo, "f.txt", "utf-16be"))
  t.assert_true(staged.ok, tostring(staged.err))
  t.assert_eq("\254\255\0O\0N\0E\216\061\222\066\0\n\0t\0w\0o", index_bytes(repo, "f.txt"), "BE bytes")
  local unstaged = unstage(repo, { 1, 1 }, index_snapshot(repo, "f.txt", "utf-16be"))
  t.assert_true(unstaged.ok, tostring(unstaged.err))
  t.assert_eq(base, index_bytes(repo, "f.txt"), "exact BE round-trip")
end)

t:test("Unicode encode failure leaves the index intact and releases the FIFO", function()
  for _, case in ipairs({ { "ucs-2", "🙂\n", "non-BMP" }, { "utf-16", "\255\n", "invalid UTF-8" } }) do
    local base = encoding_fixture.write(t, "one\n", case[1], true)
    local repo = committed_repo(base)
    local object = index_object(repo, "f.txt")
    local calls, hash_object = 0, stl.git.act.hash_object
    local restore = t:patch_table(stl.git.act, "hash_object", function(...)
      calls = calls + 1
      return hash_object(...)
    end)
    local document = staging.from_text(case[2], { encoding = case[1], bomb = true })
    local failed = stage(repo, document, { 1, 1 })
    t.assert_false(failed.ok, "invalid encoding refused")
    t.assert_true(failed.err ~= nil and failed.err:find(case[3], 1, true) ~= nil, tostring(failed.err))
    t.assert_eq(0, calls, "hash-object not reached")
    t.assert_eq(object, index_object(repo, "f.txt"), "index identity unchanged")
    t.assert_eq(base, index_bytes(repo, "f.txt"), "index bytes unchanged")
    local valid = staging.from_text("ONE\n", { encoding = case[1], bomb = true })
    local recovered = stage(repo, valid, { 1, 1 })
    t.assert_true(recovered.ok, tostring(recovered.err))
    t.assert_eq(1, calls, "next write can hash")
    restore()
    t.assert_eq(encoding_fixture.write(t, "ONE\n", case[1], true), index_bytes(repo, "f.txt"), "next write completed")
  end
end)

t:test("malformed index Unicode is rejected before staging; the next write can proceed", function()
  for _, case in ipairs({
    { "utf-16", "\254\255\0a\0", "truncated" },
    { "ucs-4le", "\255\254\0\0\0\0\017\0", "scalar" },
    { "utf-16", "\255\254a\0", "byte order" },
  }) do
    local repo = committed_repo(case[2])
    local object = index_object(repo, "f.txt")
    local document = staging.from_text("new\n", { encoding = case[1], bomb = true })
    local failed = stage(repo, document, { 1, 1 }, { document = document, object_name = object })
    t.assert_false(failed.ok, "malformed index refused")
    t.assert_true(failed.err ~= nil and failed.err:find(case[3], 1, true) ~= nil, tostring(failed.err))
    t.assert_eq(object, index_object(repo, "f.txt"), "index identity unchanged")
    t.assert_eq(case[2], index_bytes(repo, "f.txt"), "index bytes unchanged")
    local recovered = stage(repo, staging.from_text("recovered\n"), { 1, 100 })
    t.assert_true(recovered.ok, tostring(recovered.err))
    t.assert_eq("recovered\n", index_bytes(repo, "f.txt"), "UTF-8 byte-preserving path can still write")
  end
end)

t:test("malformed HEAD Unicode refuses unstage without blocking later staging", function()
  local repo = make_repo()
  fs.write(repo .. "/f.txt", "\254\255\216\0")
  git.commit(repo, "malformed HEAD")
  local valid = encoding_fixture.write(t, "one\n", "utf-16", true)
  fs.write(repo .. "/f.txt", valid)
  git.run(repo, { "add", "f.txt" })
  local snapshot = index_snapshot(repo, "f.txt", "utf-16")
  local failed = unstage(repo, { 1, 1 }, snapshot)
  t.assert_false(failed.ok, "malformed HEAD refused")
  t.assert_true(failed.err ~= nil and failed.err:find("surrogate", 1, true) ~= nil, tostring(failed.err))
  t.assert_eq(snapshot.object_name, index_object(repo, "f.txt"), "index identity unchanged")
  t.assert_eq(valid, index_bytes(repo, "f.txt"), "index bytes unchanged")
  local recovered = stage(repo, staging.from_text("ONE\n", { encoding = "utf-16", bomb = true }), { 1, 1 })
  t.assert_true(recovered.ok, tostring(recovered.err))
  t.assert_eq(encoding_fixture.write(t, "ONE\n", "utf-16", true), index_bytes(repo, "f.txt"), "next write completed")
end)

t:run()
