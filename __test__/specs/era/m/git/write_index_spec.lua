--- Run with: nvim -l __test__/run.lua __test__/specs/era/m/git/write_index_spec.lua
---@diagnostic disable: undefined-global

local bootstrap = require("__test__.support.bootstrap")
local harness = require("__test__.support.harness")

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
  m = { git = { diff = require("era.m.git.diff"), staging = require("era.m.git.staging") } },
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

t:test("writes: an asynchronous reconstruction error releases the per-file lock", function()
  local repo = make_repo()
  write(repo .. "/f.txt", "a\nb\n")
  git(repo, "add", "f.txt")
  git(repo, "commit", "-qm", "base")
  local document = staging.from_text("A\nb\n")

  local restore = t:patch_table(staging, "apply_line_changes", function()
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

t:test("writes: a synchronous hash exception preserves the result contract and releases the lock", function()
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
end)

t:run()
