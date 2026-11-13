local bootstrap = require("__test__.support.bootstrap")
local fs = require("__test__.support.fs")
local git = require("__test__.support.git")
local git_buffer = require("__test__.support.git_buffer")
local harness = require("__test__.support.harness")

local t = harness.new()
local writes = git_buffer.index_writes(t)
local buffer, staging = writes.buffer, writes.staging
local make_repo, committed_repo = writes.make_repo, writes.committed_repo
local index_bytes, index_object, index_snapshot = writes.index_bytes, writes.index_object, writes.index_snapshot
local stage, unstage = writes.stage, writes.unstage

---@param repo                          string
---@param relpath                       string
---@return string
local function index_mode(repo, relpath)
  local output = git.run(repo, { "ls-files", "--stage", "--", relpath }) ---@type string
  return output:match("^(%d+)") or ""
end

for _, case in ipairs({
  {
    name = "stage: one selected hunk leaves the other unstaged",
    base = "a\nb\nc\n",
    text = "A\nb\nC\n",
    expected = "A\nb\nc\n",
    message = "first hunk only",
  },
  {
    name = "stage: top insertion preserves the zero original anchor",
    base = "b\nc\n",
    text = "a\nb\nc\n",
    expected = "a\nb\nc\n",
    message = "inserted before line 1",
  },
  {
    name = "stage: CRLF is reconstructed before Git clean filters",
    base = "aa\r\nbb\r\ncc\r\n",
    autocrlf = "false",
    text = "AA\r\nbb\r\nCC\r\n",
    expected = "AA\r\nbb\r\ncc\r\n",
    message = "CRLF preserved",
  },
  {
    name = "stage: autocrlf clean filter matches Git index form",
    base = "aa\r\nbb\r\ncc\r\n",
    autocrlf = "true",
    text = "AA\r\nbb\r\nCC\r\n",
    expected = "AA\nbb\ncc\n",
    message = "clean-filter output",
  },
  {
    name = "stage: missing final newline is not invented",
    base = "one\ntwo\nthree",
    text = "ONE\ntwo\nthree",
    expected = "ONE\ntwo\nthree",
    message = "no final newline",
  },
}) do
  t:test(case.name, function()
    local repo = committed_repo(case.base, case.autocrlf)

    local result = stage(repo, staging.from_text(case.text), { 1, 1 })
    t.assert_true(result.ok, "staged: " .. tostring(result.err))
    t.assert_eq(case.expected, index_bytes(repo, "f.txt"), case.message)
  end)
end

t:test("stage/unstage: empty output is a valid change, not a missing selection", function()
  local repo = committed_repo("a\n")
  t.assert_true(stage(repo, staging.from_text(""), { 1, 1 }).ok, "entire deletion staged")
  t.assert_eq("", index_bytes(repo, "f.txt"), "empty blob")
  t.assert_true(unstage(repo, { 1, 1 }).ok, "entire deletion unstaged")
  t.assert_eq("a\n", index_bytes(repo, "f.txt"), "HEAD restored")
end)

t:test("stage: nothing to stage is refused at the cursor or in the selection, as the caller asked", function()
  local repo = committed_repo("a\nb\n")
  local reasons = {} ---@type string[]
  for _, partial in ipairs({ false, true }) do
    local result = git_buffer.outcome(buffer.stage_range({
      buffer_document = staging.from_text("a\nb\n"),
      expected_index = index_snapshot(repo, "f.txt"),
      partial = partial,
      range = { 1, 1 },
      relpath = "f.txt",
      toplevel = repo,
    }))
    t.assert_false(result.ok, "refused")
    reasons[#reasons + 1] = result.err
  end

  t.assert_same({ "No hunk at cursor", "No unstaged change in the selection" }, reasons)
end)

-- Each failure is injected into one write, which must leave the index as it was and let the next write proceed.
for _, case in ipairs({
  {
    name = "native reconstruction failure leaves the index intact and releases the FIFO",
    err = "does not match",
    inject = function()
      local run_diff = era.m.git.diff.run_diff
      return t:patch_table(era.m.git.diff, "run_diff", function(...)
        local hunks = run_diff(...)
        hunks[1].removed.start = 100
        return hunks
      end)
    end,
  },
  {
    name = "writes: an asynchronous reconstruction error releases the repository queue",
    inject = function()
      return t:patch_table(staging, "apply_selection", function()
        error("injected reconstruction failure")
      end)
    end,
  },
  {
    name = "writes: a synchronous hash exception preserves the result contract and releases the repository queue",
    inject = function()
      return t:patch_table(stl.git.act, "hash_object", function()
        error("injected synchronous hash failure")
      end)
    end,
  },
}) do
  t:test(case.name, function()
    local repo = committed_repo("a\nb\n")
    local document = staging.from_text("A\nb\n")

    local restore = case.inject()
    local failed = stage(repo, document, { 1, 1 })
    t.assert_false(failed.ok, "failed")
    t.assert_true(type(failed.err) == "string", "structured error")
    if case.err then
      t.assert_true(failed.err:find(case.err, 1, true) ~= nil, "native error preserved: " .. failed.err)
    end
    t.assert_eq("a\nb\n", index_bytes(repo, "f.txt"), "no partial write")

    restore()
    local retried = stage(repo, document, { 1, 1 })
    t.assert_true(retried.ok, "retry: " .. tostring(retried.err))
    t.assert_eq("A\nb\n", index_bytes(repo, "f.txt"), "written after retry")
  end)
end

t:test("stage: existing executable mode is preserved", function()
  local repo = make_repo()
  fs.write(repo .. "/f.txt", "#!/bin/sh\none\ntwo\n")
  vim.fn.setfperm(repo .. "/f.txt", "rwxr-xr-x")
  git.commit(repo, "base")

  t.assert_true(stage(repo, staging.from_text("#!/bin/sh\nONE\ntwo\n"), { 2, 2 }).ok, "staged")
  t.assert_eq("100755", index_mode(repo, "f.txt"), "mode")
end)

t:test("stage: an untracked file gets an index entry without intent-to-add", function()
  local repo = make_repo()
  local document = staging.from_text("one\ntwo\n")
  local result = git_buffer.outcome(buffer.stage_range({
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
end)

t:test("stage: a missing index entry reuses the executable mode from HEAD", function()
  local repo = make_repo()
  fs.write(repo .. "/f.txt", "#!/bin/sh\none\n")
  vim.fn.setfperm(repo .. "/f.txt", "rwxr-xr-x")
  git.commit(repo, "base")
  git.run(repo, { "rm", "-q", "--cached", "f.txt" })

  local document = staging.from_text("#!/bin/sh\nONE\n")
  local result = git_buffer.outcome(buffer.stage_range({
    buffer_document = document,
    expected_index = { document = staging.from_text(""), object_name = nil },
    partial = true,
    range = { 2, 2 },
    relpath = "f.txt",
    toplevel = repo,
  }))

  t.assert_true(result.ok, "staged")
  t.assert_eq("100755", index_mode(repo, "f.txt"), "HEAD mode")
end)

t:test("stage: safecrlf rejection leaves the index unchanged and is reported once", function()
  local reports = bootstrap.with_reporter(t)
  local repo = make_repo("true")
  git.run(repo, { "config", "core.safecrlf", "true" })
  fs.write(repo .. "/f.txt", "aa\r\nbb\r\ncc\r\n")
  git.commit(repo, "base")
  local before = index_bytes(repo, "f.txt")

  local result = stage(repo, staging.from_text("AA\r\nbb\r\nCC\r\n"), { 1, 1 })
  t.assert_false(result.ok, "Git rejected mixed document text")
  t.assert_nil(result.err, "the failing Git command reported it")
  t.assert_same({ "Failed to hash object" }, bootstrap.messages(reports.warn), "one report")
  t.assert_eq(before, index_bytes(repo, "f.txt"), "index unchanged")
end)

t:test("stage: a locked index leaves the index unchanged and is reported once", function()
  local reports = bootstrap.with_reporter(t)
  local repo = committed_repo("a\nb\n")
  local before = index_bytes(repo, "f.txt")
  fs.write(repo .. "/.git/index.lock", "")

  local result = stage(repo, staging.from_text("A\nb\n"), { 1, 1 })
  t.assert_false(result.ok, "Git refused the locked index")
  t.assert_nil(result.err, "the failing Git command reported it")
  t.assert_same({ "Failed to update index" }, bootstrap.messages(reports.warn), "one report")
  t.assert_true(reports.warn[1].details.stderr:find("index.lock", 1, true) ~= nil, "Git's reason")
  t.assert_eq(before, index_bytes(repo, "f.txt"), "index unchanged")
end)

for _, case in ipairs({
  {
    name = "unstage: a staged deletion restores lines without reordering",
    base = "a\nb\nc\nd\n",
    staged = "a\nc\nd\n",
    range = { 1, 1 },
    expected = "a\nb\nc\nd\n",
    message = "HEAD restored",
  },
  {
    name = "unstage: one selected hunk leaves the other staged",
    base = "a\nb\nc\n",
    staged = "A\nb\nC\n",
    range = { 1, 1 },
    expected = "a\nb\nC\n",
    message = "second hunk remains",
  },
  {
    name = "unstage: final newline returns with the selected HEAD line",
    base = "a\nb\n",
    staged = "a\nB",
    range = { 2, 2 },
    expected = "a\nb\n",
    message = "newline restored",
  },
}) do
  t:test(case.name, function()
    local repo = committed_repo(case.base)
    fs.write(repo .. "/f.txt", case.staged)
    git.run(repo, { "add", "f.txt" })

    local result = unstage(repo, case.range)
    t.assert_true(result.ok, "unstaged: " .. tostring(result.err))
    t.assert_eq(case.expected, index_bytes(repo, "f.txt"), case.message)
  end)
end

t:test("working-buffer unstage refuses unsafe coordinate projection", function()
  local outcome = nil ---@type table|nil
  buffer.unstage_hunk(0):finally(function(_, result)
    outcome = result
  end)

  t.assert_true(outcome ~= nil, "settled")
  ---@diagnostic disable-next-line: need-check-nil
  t.assert_false(outcome.ok, "refused")
end)

t:test("writes: a stale index snapshot refuses without changing the index", function()
  local repo = committed_repo("a\nb\n")
  local stale = index_snapshot(repo, "f.txt")
  fs.write(repo .. "/f.txt", "A\nb\n")
  git.run(repo, { "add", "f.txt" })
  local before = index_bytes(repo, "f.txt")

  local result = unstage(repo, { 1, 1 }, stale)
  t.assert_false(result.ok, "refused")
  t.assert_eq(before, index_bytes(repo, "f.txt"), "index unchanged")
end)

t:test("writes: a BOM-only concurrent index change is stale", function()
  local repo = committed_repo("a\nb\n")
  local stale = index_snapshot(repo, "f.txt")

  local bom_bytes = "\239\187\191a\nb\n"
  local hash = assert(git.run(repo, { "hash-object", "-w", "--stdin" }, bom_bytes):match("(%x+)"))
  git.run(repo, { "update-index", "--cacheinfo", "100644," .. hash .. ",f.txt" })

  local result = stage(repo, staging.from_text("A\nb\n"), { 1, 1 }, stale)
  t.assert_false(result.ok, "refused")
  t.assert_eq(bom_bytes, index_bytes(repo, "f.txt"), "concurrent bytes unchanged")
end)

t:test("writes: different files share one repository FIFO", function()
  local repo = make_repo()
  fs.write(repo .. "/a.txt", "a\n")
  fs.write(repo .. "/b.txt", "b\n")
  git.commit(repo, "base")

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
  local first_result = git_buffer.outcome(first)
  local second_result = git_buffer.outcome(second)
  restore()

  t.assert_true(first_result.ok, "first write")
  t.assert_true(second_result.ok, "second write")
  t.assert_eq("a.txt,b.txt", table.concat(starts, ","), "FIFO start order")
  t.assert_eq("A\n", index_bytes(repo, "a.txt"), "first index entry")
  t.assert_eq("B\n", index_bytes(repo, "b.txt"), "second index entry")
end)

-- Each query answers the write's index lookup with a failure or an entry it must refuse.
for _, case in ipairs({
  {
    name = "stage: index blob read failure leaves the index unchanged",
    query = "get_show_blob",
    result = { ok = false, missing = false, err = "injected index read failure" },
  },
  {
    name = "stage: index metadata failure leaves the index unchanged",
    query = "get_file_info",
    result = { ok = false, missing = false, err = "injected metadata failure" },
  },
  {
    name = "stage: unmerged index entry is refused",
    query = "get_file_info",
    result = { ok = true, missing = false, info = { has_conflicts = true, relpath = "f.txt" } },
  },
}) do
  t:test(case.name, function()
    local repo = committed_repo("a\nb\n")
    local before = index_bytes(repo, "f.txt")

    local restore = t:patch_table(stl.git.info, case.query, function()
      return stl.c.Future.resolve(vim.deepcopy(case.result))
    end)
    local result = stage(repo, staging.from_text("A\nb\n"), { 1, 1 })
    restore()

    t.assert_false(result.ok, "refused")
    t.assert_eq(before, index_bytes(repo, "f.txt"), "index unchanged")
  end)
end

t:test("stage: HEAD mode lookup failure does not default to regular file", function()
  local repo = make_repo()
  fs.write(repo .. "/f.txt", "#!/bin/sh\none\n")
  vim.fn.setfperm(repo .. "/f.txt", "rwxr-xr-x")
  git.commit(repo, "base")
  git.run(repo, { "rm", "-q", "--cached", "f.txt" })

  local restore = t:patch_table(stl.git.info, "get_head_file_mode", function()
    return stl.c.Future.resolve({ ok = false, missing = false, err = "injected mode failure" })
  end)
  local result = git_buffer.outcome(buffer.stage_range({
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
end)

t:test("unstage: HEAD blob read failure leaves the index unchanged", function()
  local repo = committed_repo("a\nb\n")
  fs.write(repo .. "/f.txt", "A\nb\n")
  git.run(repo, { "add", "f.txt" })
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
end)

t:run()
