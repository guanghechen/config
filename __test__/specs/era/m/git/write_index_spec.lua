--- Run with: nvim -l __test__/run.lua __test__/specs/era/m/git/write_index_spec.lua
---@diagnostic disable: undefined-global

local bootstrap = require("__test__.support.bootstrap")
local harness = require("__test__.support.harness")
local encoding_fixture = require("__test__.fixtures.era.m.git.encoding")

local t = harness.new("era.m.git.write_index")
bootstrap.with_stl_c(t)
bootstrap.with_global(t, "stl", {
  c = { Ticker = {
    new = function()
      return {}
    end,
  } },
  git = { act = require("stl.git.act"), info = require("stl.git.info") },
  reporter = { warn = function() end },
})
bootstrap.with_global(t, "yoz", {
  canonical_path = {
    to_os_path = function(filepath)
      return filepath
    end,
  },
})
bootstrap.with_global(t, "era", {
  m = {
    git = {
      diff = require("era.m.git.diff"),
      index = require("era.m.git.index"),
      staging = require("era.m.git.staging"),
    },
  },
})

local staging = era.m.git.staging
local buffer = assert(loadfile("lua/era/m/git/buffer.lua"))() ---@type era.m.git.buffer

---@param repo                          string
---@param ...                           string
---@return vim.SystemCompleted
local function git(repo, ...)
  return vim.system({ "git", "-C", repo, ... }, { text = false }):wait()
end

---@param autocrlf                      string|nil
---@return string
local function make_repo(autocrlf)
  local repo = vim.fn.tempname() ---@type string
  vim.fn.mkdir(repo, "p")
  git(repo, "init", "-q")
  git(repo, "config", "user.email", "test@test")
  git(repo, "config", "user.name", "test")
  git(repo, "config", "core.autocrlf", autocrlf or "false")
  git(repo, "config", "core.safecrlf", "false")
  return repo
end

---@param filepath                      string
---@param bytes                         string
local function write(filepath, bytes)
  local file = assert(io.open(filepath, "wb"))
  file:write(bytes)
  file:close()
end

---@param repo                          string
---@param relpath                       string
---@return string
local function index_bytes(repo, relpath)
  return git(repo, "cat-file", "-p", ":" .. relpath).stdout or ""
end

---@param repo                          string
---@param relpath                       string
---@return string
local function index_mode(repo, relpath)
  local output = git(repo, "ls-files", "--stage", "--", relpath).stdout or "" ---@type string
  return output:match("^(%d+)") or ""
end

---@param repo                          string
---@param relpath                       string
---@return string|nil
local function index_object(repo, relpath)
  local output = git(repo, "ls-files", "--stage", "--", relpath).stdout or "" ---@type string
  return output:match("^%d+%s+(%x+)%s+0%s+")
end

---@param repo                          string
---@param relpath                       string
---@param encoding                      string|nil
---@return era.m.git.Document
local function index_document(repo, relpath, encoding)
  return assert(staging.from_blob(index_bytes(repo, relpath), encoding or "utf-8", "\n"))
end

---@param repo                          string
---@param relpath                       string
---@param encoding                      string|nil
---@return era.m.git.buffer.IIndexSnapshot
local function index_snapshot(repo, relpath, encoding)
  return {
    document = index_document(repo, relpath, encoding),
    object_name = index_object(repo, relpath),
  }
end

---@param future                        stl.c.Future
---@return { ok: boolean, err: string|nil }
local function wait(future)
  local outcome = nil ---@type table|nil
  future:finally(function(resolved, result)
    outcome = resolved and result or { ok = false, err = tostring(result) }
  end)
  vim.wait(5000, function()
    return outcome ~= nil
  end)
  return assert(outcome, "operation did not settle")
end

---@param repo                          string
---@param document                      era.m.git.Document
---@param range                         { [1]: integer, [2]: integer }
---@param expected                      era.m.git.buffer.IIndexSnapshot|nil
---@return { ok: boolean, err: string|nil }
local function stage(repo, document, range, expected)
  expected = expected or index_snapshot(repo, "f.txt", document.encoding)
  return wait(buffer.stage_range({
    buffer_document = document,
    expected_index = expected,
    partial = true,
    range = range,
    relpath = "f.txt",
    toplevel = repo,
  }))
end

---@param repo                          string
---@param range                         { [1]: integer, [2]: integer }
---@param expected                      era.m.git.buffer.IIndexSnapshot|nil
---@return { ok: boolean, err: string|nil }
local function unstage(repo, range, expected)
  expected = expected or index_snapshot(repo, "f.txt")
  return wait(buffer.unstage_range({
    expected_index = expected,
    range = range,
    relpath = "f.txt",
    toplevel = repo,
  }))
end

t:test("stage: one selected hunk leaves the other unstaged", function()
  local repo = make_repo()
  write(repo .. "/f.txt", "a\nb\nc\n")
  git(repo, "add", "f.txt")
  git(repo, "commit", "-qm", "base")

  t.assert_true(stage(repo, staging.from_text("A\nb\nC\n"), { 1, 1 }).ok, "staged")
  t.assert_eq("A\nb\nc\n", index_bytes(repo, "f.txt"), "first hunk only")
  vim.fn.delete(repo, "rf")
end)

t:test("stage: top insertion preserves the zero original anchor", function()
  local repo = make_repo()
  write(repo .. "/f.txt", "b\nc\n")
  git(repo, "add", "f.txt")
  git(repo, "commit", "-qm", "base")

  t.assert_true(stage(repo, staging.from_text("a\nb\nc\n"), { 1, 1 }).ok, "staged")
  t.assert_eq("a\nb\nc\n", index_bytes(repo, "f.txt"), "inserted before line 1")
  vim.fn.delete(repo, "rf")
end)

t:test("stage: CRLF is reconstructed before Git clean filters", function()
  local repo = make_repo("false")
  write(repo .. "/f.txt", "aa\r\nbb\r\ncc\r\n")
  git(repo, "add", "f.txt")
  git(repo, "commit", "-qm", "base")

  local document = staging.from_text("AA\r\nbb\r\nCC\r\n")
  local result = stage(repo, document, { 1, 1 })
  t.assert_true(result.ok, "staged: " .. tostring(result.err))
  t.assert_eq("AA\r\nbb\r\ncc\r\n", index_bytes(repo, "f.txt"), "CRLF preserved")
  vim.fn.delete(repo, "rf")
end)

t:test("stage: autocrlf clean filter matches Git index form", function()
  local repo = make_repo("true")
  write(repo .. "/f.txt", "aa\r\nbb\r\ncc\r\n")
  git(repo, "add", "f.txt")
  git(repo, "commit", "-qm", "base")

  local document = staging.from_text("AA\r\nbb\r\nCC\r\n")
  local result = stage(repo, document, { 1, 1 })
  t.assert_true(result.ok, "staged: " .. tostring(result.err))
  t.assert_eq("AA\nbb\ncc\n", index_bytes(repo, "f.txt"), "clean-filter output")
  vim.fn.delete(repo, "rf")
end)

t:test("stage: missing final newline is not invented", function()
  local repo = make_repo()
  write(repo .. "/f.txt", "one\ntwo\nthree")
  git(repo, "add", "f.txt")
  git(repo, "commit", "-qm", "base")

  t.assert_true(stage(repo, staging.from_text("ONE\ntwo\nthree"), { 1, 1 }).ok, "staged")
  t.assert_eq("ONE\ntwo\nthree", index_bytes(repo, "f.txt"), "no final newline")
  vim.fn.delete(repo, "rf")
end)

t:test("stage: latin1 content is encoded before hashing", function()
  local repo = make_repo()
  local base = assert(vim.iconv("caf\195\169\nx\n", "utf-8", "latin1"))
  write(repo .. "/f.txt", base)
  git(repo, "add", "f.txt")
  git(repo, "commit", "-qm", "base")

  local document = staging.from_text("CAF\195\137\nx\n", { encoding = "latin1" })
  t.assert_true(stage(repo, document, { 1, 1 }, index_snapshot(repo, "f.txt", "latin1")).ok, "staged")
  t.assert_eq(assert(vim.iconv("CAF\195\137\nx\n", "utf-8", "latin1")), index_bytes(repo, "f.txt"), "latin1 bytes")
  vim.fn.delete(repo, "rf")
end)

for _, format in ipairs(encoding_fixture.formats) do
  t:test(format.name .. ": unsaved partial stage/unstage matches Neovim file bytes", function()
    for _, bomb in ipairs({ false, true }) do
      for _, fileformat in ipairs({ "unix", "dos" }) do
        for _, eof in ipairs({ "", "\n" }) do
          local repo = make_repo()
          t:defer(function()
            vim.fn.delete(repo, "rf")
          end)
          local prefix = bomb and "\239\187\191" or ""
          local base_text = prefix .. "café中\nmiddle\nlast" .. eof
          local base, bufnr = encoding_fixture.write(t, base_text, format.name, bomb, fileformat)
          write(repo .. "/f.txt", base)
          t.assert_eq(0, git(repo, "add", "f.txt").code)
          t.assert_eq(0, git(repo, "commit", "-qm", "base").code)
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
          local file = assert(io.open(repo .. "/f.txt", "rb"))
          local close = t:defer(function()
            file:close()
          end)
          local working_bytes = file:read("*a")
          close()
          t.assert_eq(base, working_bytes, "worktree unchanged")
        end
      end
    end
  end)
end

t:test("UTF-16BE alias stages actual BE bytes, including an astral character", function()
  local base = "\254\255\0o\0n\0e\0\n\0t\0w\0o"
  local repo = make_repo()
  t:defer(function()
    vim.fn.delete(repo, "rf")
  end)
  write(repo .. "/f.txt", base)
  git(repo, "add", "f.txt")
  git(repo, "commit", "-qm", "base")
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
    local repo = make_repo()
    t:defer(function()
      vim.fn.delete(repo, "rf")
    end)
    local base = encoding_fixture.write(t, "one\n", case[1], true)
    write(repo .. "/f.txt", base)
    git(repo, "add", "f.txt")
    git(repo, "commit", "-qm", "base")
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
    local repo = make_repo()
    t:defer(function()
      vim.fn.delete(repo, "rf")
    end)
    write(repo .. "/f.txt", case[2])
    git(repo, "add", "f.txt")
    git(repo, "commit", "-qm", "base")
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
  t:defer(function()
    vim.fn.delete(repo, "rf")
  end)
  write(repo .. "/f.txt", "\254\255\216\0")
  git(repo, "add", "f.txt")
  git(repo, "commit", "-qm", "malformed HEAD")
  local valid = encoding_fixture.write(t, "one\n", "utf-16", true)
  write(repo .. "/f.txt", valid)
  git(repo, "add", "f.txt")
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

t:test("stage/unstage: empty output is a valid change, not a missing selection", function()
  local repo = make_repo()
  t:defer(function()
    vim.fn.delete(repo, "rf")
  end)
  write(repo .. "/f.txt", "a\n")
  git(repo, "add", "f.txt")
  git(repo, "commit", "-qm", "base")
  t.assert_true(stage(repo, staging.from_text(""), { 1, 1 }).ok, "entire deletion staged")
  t.assert_eq("", index_bytes(repo, "f.txt"), "empty blob")
  t.assert_true(unstage(repo, { 1, 1 }).ok, "entire deletion unstaged")
  t.assert_eq("a\n", index_bytes(repo, "f.txt"), "HEAD restored")
end)

t:test("native reconstruction failure leaves the index intact and releases the FIFO", function()
  local repo = make_repo()
  t:defer(function()
    vim.fn.delete(repo, "rf")
  end)
  write(repo .. "/f.txt", "a\nb\n")
  git(repo, "add", "f.txt")
  git(repo, "commit", "-qm", "base")
  local document = staging.from_text("A\nb\n")
  local run_diff = era.m.git.diff.run_diff
  local restore = t:patch_table(era.m.git.diff, "run_diff", function(...)
    local hunks = run_diff(...)
    hunks[1].removed.start = 100
    return hunks
  end)
  local failed = stage(repo, document, { 1, 1 })
  t.assert_false(failed.ok, "invalid native input refused")
  t.assert_true(failed.err:find("does not match", 1, true) ~= nil, "native error preserved")
  t.assert_eq("a\nb\n", index_bytes(repo, "f.txt"), "no partial write")
  restore()
  t.assert_true(stage(repo, document, { 1, 1 }).ok, "subsequent write can proceed")
end)

t:test("stage: existing executable mode is preserved", function()
  local repo = make_repo()
  write(repo .. "/f.txt", "#!/bin/sh\none\ntwo\n")
  vim.fn.setfperm(repo .. "/f.txt", "rwxr-xr-x")
  git(repo, "add", "f.txt")
  git(repo, "commit", "-qm", "base")

  t.assert_true(stage(repo, staging.from_text("#!/bin/sh\nONE\ntwo\n"), { 2, 2 }).ok, "staged")
  t.assert_eq("100755", index_mode(repo, "f.txt"), "mode")
  vim.fn.delete(repo, "rf")
end)

t:test("stage: an untracked file gets an index entry without intent-to-add", function()
  local repo = make_repo()
  local document = staging.from_text("one\ntwo\n")
  local result = wait(buffer.stage_range({
    buffer_document = document,
    expected_index = { document = staging.from_text(""), object_name = nil },
    partial = true,
    range = { 1, 1 },
    relpath = "f.txt",
    toplevel = repo,
  }))

  t.assert_true(result.ok, "staged")
  t.assert_eq("one\n", index_bytes(repo, "f.txt"), "selected line")
  t.assert_eq("100644", index_mode(repo, "f.txt"), "new mode")
  vim.fn.delete(repo, "rf")
end)

t:test("stage: a missing index entry reuses the executable mode from HEAD", function()
  local repo = make_repo()
  write(repo .. "/f.txt", "#!/bin/sh\none\n")
  vim.fn.setfperm(repo .. "/f.txt", "rwxr-xr-x")
  git(repo, "add", "f.txt")
  git(repo, "commit", "-qm", "base")
  git(repo, "rm", "-q", "--cached", "f.txt")

  local document = staging.from_text("#!/bin/sh\nONE\n")
  local result = wait(buffer.stage_range({
    buffer_document = document,
    expected_index = { document = staging.from_text(""), object_name = nil },
    partial = true,
    range = { 2, 2 },
    relpath = "f.txt",
    toplevel = repo,
  }))

  t.assert_true(result.ok, "staged")
  t.assert_eq("100755", index_mode(repo, "f.txt"), "HEAD mode")
  vim.fn.delete(repo, "rf")
end)

t:test("stage: safecrlf rejection leaves the index unchanged", function()
  local repo = make_repo("true")
  git(repo, "config", "core.safecrlf", "true")
  write(repo .. "/f.txt", "aa\r\nbb\r\ncc\r\n")
  git(repo, "add", "f.txt")
  git(repo, "commit", "-qm", "base")
  local before = index_bytes(repo, "f.txt")

  local result = stage(repo, staging.from_text("AA\r\nbb\r\nCC\r\n"), { 1, 1 })
  t.assert_false(result.ok, "Git rejected mixed document text")
  t.assert_eq(before, index_bytes(repo, "f.txt"), "index unchanged")
  vim.fn.delete(repo, "rf")
end)

t:test("unstage: a staged deletion restores lines without reordering", function()
  local repo = make_repo()
  write(repo .. "/f.txt", "a\nb\nc\nd\n")
  git(repo, "add", "f.txt")
  git(repo, "commit", "-qm", "base")
  write(repo .. "/f.txt", "a\nc\nd\n")
  git(repo, "add", "f.txt")

  t.assert_true(unstage(repo, { 1, 1 }).ok, "unstaged")
  t.assert_eq("a\nb\nc\nd\n", index_bytes(repo, "f.txt"), "HEAD restored")
  vim.fn.delete(repo, "rf")
end)

t:test("unstage: one selected hunk leaves the other staged", function()
  local repo = make_repo()
  write(repo .. "/f.txt", "a\nb\nc\n")
  git(repo, "add", "f.txt")
  git(repo, "commit", "-qm", "base")
  write(repo .. "/f.txt", "A\nb\nC\n")
  git(repo, "add", "f.txt")

  t.assert_true(unstage(repo, { 1, 1 }).ok, "unstaged")
  t.assert_eq("a\nb\nC\n", index_bytes(repo, "f.txt"), "second hunk remains")
  vim.fn.delete(repo, "rf")
end)

t:test("unstage: final newline returns with the selected HEAD line", function()
  local repo = make_repo()
  write(repo .. "/f.txt", "a\nb\n")
  git(repo, "add", "f.txt")
  git(repo, "commit", "-qm", "base")
  write(repo .. "/f.txt", "a\nB")
  git(repo, "add", "f.txt")

  t.assert_true(unstage(repo, { 2, 2 }).ok, "unstaged")
  t.assert_eq("a\nb\n", index_bytes(repo, "f.txt"), "newline restored")
  vim.fn.delete(repo, "rf")
end)

t:test("writes: a stale index snapshot refuses without changing the index", function()
  local repo = make_repo()
  write(repo .. "/f.txt", "a\nb\n")
  git(repo, "add", "f.txt")
  git(repo, "commit", "-qm", "base")
  local stale = index_snapshot(repo, "f.txt")
  write(repo .. "/f.txt", "A\nb\n")
  git(repo, "add", "f.txt")
  local before = index_bytes(repo, "f.txt")

  local result = unstage(repo, { 1, 1 }, stale)
  t.assert_false(result.ok, "refused")
  t.assert_eq(before, index_bytes(repo, "f.txt"), "index unchanged")
  vim.fn.delete(repo, "rf")
end)

t:test("writes: a BOM-only concurrent index change is stale", function()
  local repo = make_repo()
  write(repo .. "/f.txt", "a\nb\n")
  git(repo, "add", "f.txt")
  git(repo, "commit", "-qm", "base")
  local stale = index_snapshot(repo, "f.txt")

  local bom_bytes = "\239\187\191a\nb\n"
  local hashed = vim
    .system({ "git", "-C", repo, "hash-object", "-w", "--stdin" }, { stdin = bom_bytes, text = false })
    :wait()
  local hash = assert((hashed.stdout or ""):match("(%x+)"))
  git(repo, "update-index", "--cacheinfo", "100644," .. hash .. ",f.txt")

  local result = stage(repo, staging.from_text("A\nb\n"), { 1, 1 }, stale)
  t.assert_false(result.ok, "refused")
  t.assert_eq(bom_bytes, index_bytes(repo, "f.txt"), "concurrent bytes unchanged")
  vim.fn.delete(repo, "rf")
end)

t:test("writes: different files share one repository FIFO", function()
  local repo = make_repo()
  write(repo .. "/a.txt", "a\n")
  write(repo .. "/b.txt", "b\n")
  git(repo, "add", "a.txt", "b.txt")
  git(repo, "commit", "-qm", "base")

  local original = stl.git.info.get_file_info
  local starts = {} ---@type string[]
  local release_first = nil ---@type (fun(): nil)|nil
  local restore = t:patch_table(stl.git.info, "get_file_info", function(cwd, relpath, token)
    starts[#starts + 1] = relpath
    if relpath ~= "a.txt" then
      return original(cwd, relpath, token)
    end
    return stl.c.Future.new(function(resolve, reject)
      release_first = function()
        original(cwd, relpath, token):finally(function(resolved, result)
          if resolved then
            resolve(result)
          else
            reject(result)
          end
        end)
      end
    end)
  end)

  local first = buffer.stage_range({
    buffer_document = staging.from_text("A\n"),
    expected_index = index_snapshot(repo, "a.txt"),
    partial = true,
    range = { 1, 1 },
    relpath = "a.txt",
    toplevel = repo,
  })
  local second = buffer.stage_range({
    buffer_document = staging.from_text("B\n"),
    expected_index = index_snapshot(repo, "b.txt"),
    partial = true,
    range = { 1, 1 },
    relpath = "b.txt",
    toplevel = repo,
  })

  t.assert_eq("a.txt", table.concat(starts, ","), "second write must wait")
  assert(release_first)()
  local first_result = wait(first)
  local second_result = wait(second)
  restore()

  t.assert_true(first_result.ok, "first write")
  t.assert_true(second_result.ok, "second write")
  t.assert_eq("a.txt,b.txt", table.concat(starts, ","), "FIFO start order")
  t.assert_eq("A\n", index_bytes(repo, "a.txt"), "first index entry")
  t.assert_eq("B\n", index_bytes(repo, "b.txt"), "second index entry")
  vim.fn.delete(repo, "rf")
end)

t:test("stage: index blob read failure leaves the index unchanged", function()
  local repo = make_repo()
  write(repo .. "/f.txt", "a\nb\n")
  git(repo, "add", "f.txt")
  git(repo, "commit", "-qm", "base")
  local before = index_bytes(repo, "f.txt")

  local restore = t:patch_table(stl.git.info, "get_show_blob", function()
    return stl.c.Future.resolve({ ok = false, missing = false, err = "injected index read failure" })
  end)
  local result = stage(repo, staging.from_text("A\nb\n"), { 1, 1 })
  restore()

  t.assert_false(result.ok, "refused")
  t.assert_eq(before, index_bytes(repo, "f.txt"), "index unchanged")
  vim.fn.delete(repo, "rf")
end)

t:test("stage: index metadata failure leaves the index unchanged", function()
  local repo = make_repo()
  write(repo .. "/f.txt", "a\nb\n")
  git(repo, "add", "f.txt")
  git(repo, "commit", "-qm", "base")
  local before = index_bytes(repo, "f.txt")

  local restore = t:patch_table(stl.git.info, "get_file_info", function()
    return stl.c.Future.resolve({ ok = false, missing = false, err = "injected metadata failure" })
  end)
  local result = stage(repo, staging.from_text("A\nb\n"), { 1, 1 })
  restore()

  t.assert_false(result.ok, "refused")
  t.assert_eq(before, index_bytes(repo, "f.txt"), "index unchanged")
  vim.fn.delete(repo, "rf")
end)

t:test("stage: unmerged index entry is refused", function()
  local repo = make_repo()
  write(repo .. "/f.txt", "a\nb\n")
  git(repo, "add", "f.txt")
  git(repo, "commit", "-qm", "base")
  local before = index_bytes(repo, "f.txt")

  local restore = t:patch_table(stl.git.info, "get_file_info", function()
    return stl.c.Future.resolve({
      ok = true,
      missing = false,
      info = { has_conflicts = true, relpath = "f.txt" },
    })
  end)
  local result = stage(repo, staging.from_text("A\nb\n"), { 1, 1 })
  restore()

  t.assert_false(result.ok, "refused")
  t.assert_eq(before, index_bytes(repo, "f.txt"), "index unchanged")
  vim.fn.delete(repo, "rf")
end)

t:test("stage: HEAD mode lookup failure does not default to regular file", function()
  local repo = make_repo()
  write(repo .. "/f.txt", "#!/bin/sh\none\n")
  vim.fn.setfperm(repo .. "/f.txt", "rwxr-xr-x")
  git(repo, "add", "f.txt")
  git(repo, "commit", "-qm", "base")
  git(repo, "rm", "-q", "--cached", "f.txt")

  local restore = t:patch_table(stl.git.info, "get_head_file_mode", function()
    return stl.c.Future.resolve({ ok = false, missing = false, err = "injected mode failure" })
  end)
  local result = wait(buffer.stage_range({
    buffer_document = staging.from_text("#!/bin/sh\nONE\n"),
    expected_index = { document = staging.from_text(""), object_name = nil },
    partial = true,
    range = { 2, 2 },
    relpath = "f.txt",
    toplevel = repo,
  }))
  restore()

  t.assert_false(result.ok, "refused")
  t.assert_nil(index_object(repo, "f.txt"), "index remains missing")
  vim.fn.delete(repo, "rf")
end)

t:test("unstage: HEAD blob read failure leaves the index unchanged", function()
  local repo = make_repo()
  write(repo .. "/f.txt", "a\nb\n")
  git(repo, "add", "f.txt")
  git(repo, "commit", "-qm", "base")
  write(repo .. "/f.txt", "A\nb\n")
  git(repo, "add", "f.txt")
  local before = index_bytes(repo, "f.txt")

  local original = stl.git.info.get_show_blob
  local restore = t:patch_table(stl.git.info, "get_show_blob", function(cwd, object, token)
    if object == "HEAD:f.txt" then
      return stl.c.Future.resolve({ ok = false, missing = false, err = "injected HEAD read failure" })
    end
    return original(cwd, object, token)
  end)
  local result = unstage(repo, { 1, 1 })
  restore()

  t.assert_false(result.ok, "refused")
  t.assert_eq(before, index_bytes(repo, "f.txt"), "index unchanged")
  vim.fn.delete(repo, "rf")
end)

t:test("writes: an asynchronous reconstruction error releases the repository queue", function()
  local repo = make_repo()
  write(repo .. "/f.txt", "a\nb\n")
  git(repo, "add", "f.txt")
  git(repo, "commit", "-qm", "base")
  local document = staging.from_text("A\nb\n")

  local restore = t:patch_table(staging, "apply_selection", function()
    error("injected reconstruction failure")
  end)
  local failed = stage(repo, document, { 1, 1 })
  t.assert_false(failed.ok, "failed")

  restore()
  local retried = stage(repo, document, { 1, 1 })
  t.assert_true(retried.ok, "retry")
  t.assert_eq("A\nb\n", index_bytes(repo, "f.txt"), "written after retry")
  vim.fn.delete(repo, "rf")
end)

t:test(
  "writes: a synchronous hash exception preserves the result contract and releases the repository queue",
  function()
    local repo = make_repo()
    write(repo .. "/f.txt", "a\nb\n")
    git(repo, "add", "f.txt")
    git(repo, "commit", "-qm", "base")
    local document = staging.from_text("A\nb\n")

    local restore = t:patch_table(stl.git.act, "hash_object", function()
      error("injected synchronous hash failure")
    end)
    local failed = stage(repo, document, { 1, 1 })
    t.assert_false(failed.ok, "failed")
    t.assert_true(type(failed.err) == "string", "structured error")

    restore()
    local retried = stage(repo, document, { 1, 1 })
    t.assert_true(retried.ok, "retry")
    t.assert_eq("A\nb\n", index_bytes(repo, "f.txt"), "written after retry")
    vim.fn.delete(repo, "rf")
  end
)

t:run()
