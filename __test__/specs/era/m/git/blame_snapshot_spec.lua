local harness = require("__test__.support.harness")
local t = harness.new("yoz.git.BlameSnapshot")
t:patch_global("yoz", require("yoz"))
local reference = assert(loadfile("__test__/fixtures/era/m/git/blame_lua_reference.lua"))()
local workspace = ""

---@param args                          string[]
---@param input                         ?string
---@return string
local function git(args, input)
  local command = {
    "git",
    "--no-optional-locks",
    "-C",
    workspace,
    "-c",
    "user.name=Test",
    "-c",
    "user.email=test@example.com",
    "-c",
    "commit.gpgSign=false",
    "-c",
    "core.autocrlf=false",
    "-c",
    "core.hooksPath=" .. workspace .. "/no-hooks",
  }
  vim.list_extend(command, args)
  local output = vim.system(command, { stdin = input, text = false }):wait()
  t.assert_eq(0, output.code, output.stderr)
  return output.stdout or ""
end

---@param format                        ?string
---@return string
local function new_repo(format)
  workspace = vim.fn.tempname()
  vim.fn.mkdir(workspace, "p")
  local root = workspace
  t:defer(function()
    vim.fn.delete(root, "rf")
  end)
  git({ "init", "-q", "--object-format=" .. (format or "sha1") })
  return root
end

---@param path                          string
---@param content                       string
---@return nil
local function write(path, content)
  local fd = assert(vim.uv.fs_open(path, "w", 420))
  local close = t:defer(function()
    assert(vim.uv.fs_close(fd))
  end)
  assert(vim.uv.fs_write(fd, content))
  close()
end

---@param path                          string
---@param content                       string
---@param timeout                       ?integer
---@return string
---@return yoz.git.BlameSnapshot|nil
---@return string|nil
local function query(path, content, timeout)
  local job = yoz.git.start_blame({ cwd = workspace, path = path, contents = content })
  local dispose = t:defer(function()
    job:dispose()
  end)
  local state, snapshot, err
  t.wait_until(function()
    state, snapshot, err = job:poll()
    return state ~= "running"
  end, timeout or 10000, "native blame did not finish")
  dispose()
  return state, snapshot, err
end

---@param path                          string
---@param content                       string
---@return yoz.git.BlameSnapshot
local function assert_parity(path, content)
  local state, snapshot, err = query(path, content)
  t.assert_eq("completed", state, err)
  assert(snapshot)
  local expected = reference.parse(git({ "blame", "--porcelain", "--contents", "-", "--", path }, content))
  local actual = snapshot:entries()
  t.assert_eq(#expected, #actual, "full attribution count")
  for lnum, info in ipairs(expected) do
    local entry = actual[lnum]
    local uncommitted = info.sha:match("^0+$") ~= nil or info.author == "Not Committed Yet"
    t.assert_eq(uncommitted, entry.uncommitted, "native uncommitted flag")
    entry.uncommitted = nil
    if uncommitted then
      -- Separate Git invocations timestamp their synthetic commit independently.
      for _, field in ipairs({ "author_time", "committer_time" }) do
        t.assert_true(math.abs(entry[field] - info[field]) < 20, "synthetic commit timestamp")
        entry[field] = info[field]
      end
    end
    t.assert_true(vim.deep_equal(info, entry), "porcelain fields differ at line " .. lnum)
  end
  return snapshot
end

t:test("full snapshots match the Lua oracle across history and unsaved changes", function()
  local root = new_repo()
  write(root .. "/file", "one\ntwo\nthree\nfour\n")
  git({ "add", "file" })
  git({ "commit", "-qm", "base" })
  write(root .. "/file", "one\nchanged\nthree\nfour\n")
  git({ "add", "file" })
  git({ "commit", "-qm", "second" })
  local snapshot = assert_parity("file", "UNSAVED\none\nchanged\nthree\nfour\n")
  local lines, commits = snapshot:stats()
  t.assert_eq(5, lines, "line count")
  t.assert_eq(3, commits, "deduplicated commit metadata")
  t.assert_true(snapshot:commit_at(1).uncommitted, "unsaved attribution")
  t.assert_eq("base", snapshot:commit_at(4).summary, "unchanged attribution")
  local labels = {}
  for index, commit in ipairs(snapshot:commits()) do
    labels[index] = commit.uncommitted and "unsaved" or commit.summary
  end
  t.assert_true(
    vim.deep_equal({ "unsaved", "base", "second", "base", "base" }, snapshot:annotations(labels)),
    "non-contiguous and repeated commit groups keep line order"
  )
end)

t:test("SHA-256 snapshots retain full identities and eight-character display abbreviations", function()
  local root = new_repo("sha256")
  write(root .. "/file", "one\ntwo\n")
  git({ "add", "file" })
  git({ "commit", "-qm", "base" })
  local snapshot = assert_parity("file", "one\nUNSAVED\n")
  t.assert_eq(64, #snapshot:commit_at(1).sha, "full SHA-256")
  t.assert_eq(8, #snapshot:commit_at(1).abbrev_sha, "display abbreviation")
end)

t:test("rename metadata and literal pathname bytes match the old porcelain contract", function()
  local root = new_repo()
  local suffix = package.config:sub(1, 1) == "/" and "\255" or "字"
  local old, new = "old-" .. suffix, "new-" .. suffix
  write(root .. "/" .. old, "one\ntwo\nthree\n")
  git({ "add", "--", old })
  git({ "commit", "-qm", "base" })
  git({ "mv", "--", old, new })
  git({ "commit", "-qm", "rename" })
  assert_parity(new, "one\ntwo\nthree\n")
end)

t:test("contents preserve CRLF, BOM, legacy encoding and missing final newline", function()
  for _, content in ipairs({ "one\r\ntwo\r\n", "\239\187\191one\ntwo\n", "caf\233\ntwo\n", "one\ntwo" }) do
    local root = new_repo()
    write(root .. "/file", content)
    git({ "add", "file" })
    git({ "commit", "-qm", "bytes" })
    assert_parity("file", content)
  end
end)

t:test("exports cannot mutate the snapshot and annotation projection reuses literal labels", function()
  local root = new_repo()
  write(root .. "/file", "one\ntwo\nthree\n")
  git({ "add", "file" })
  git({ "commit", "-qm", "base" })
  local snapshot = assert_parity("file", "one\ntwo\nthree\n")
  snapshot:commits()[1].author = "changed"
  snapshot:entries()[1].summary = "changed"
  t.assert_eq("Test", snapshot:commit_at(1).author, "immutable commit")
  t.assert_eq("base", snapshot:commit_at(1).summary, "immutable entry")
  local lines = snapshot:annotations({ "literal %1 <sha>" })
  t.assert_eq(3, #lines, "projected line count")
  t.assert_eq("literal %1 <sha>", lines[3], "literal label")
  t.assert_nil(snapshot:commit_at(0), "zero line is absent")
  t.assert_nil(snapshot:commit_at(4), "past EOF is absent")
  t.assert_false(pcall(snapshot.annotations, snapshot, {}), "missing label rejected")
end)

t:test("unborn HEAD and absent paths fail without returning a partial snapshot", function()
  local root = new_repo()
  write(root .. "/file", "one\n")
  local state, snapshot, err = query("file", "one\n")
  t.assert_eq("failed", state, "unborn HEAD")
  t.assert_nil(snapshot, "no partial snapshot")
  t.assert_true(type(err) == "string" and #err > 0, "Git diagnostic")
  git({ "add", "file" })
  git({ "commit", "-qm", "base" })
  state, snapshot = query("missing", "one\n")
  t.assert_eq("failed", state, "missing path")
  t.assert_nil(snapshot, "missing path has no data")
end)

t:test("annotations retain validation, byte values and array-prefix semantics", function()
  local root = new_repo()
  write(root .. "/file", "one\ntwo\n")
  git({ "add", "file" })
  git({ "commit", "-qm", "base" })
  local state, snapshot, err = query("file", "one\ntwo\n")
  t.assert_eq("completed", state, err)
  local literal = "\0\255 literal %1 <sha>"
  local labels = setmetatable({ literal }, {
    __index = function()
      error("annotation labels must use raw array entries")
    end,
    __newindex = function()
      error("input labels must not be modified")
    end,
  })
  local first = snapshot:annotations(labels)
  t.assert_true(vim.deep_equal({ literal, literal }, first), "literal byte projection")
  first[1] = "changed result"
  t.assert_true(vim.deep_equal({ literal, literal }, snapshot:annotations(labels)), "independent calls")
  t.assert_eq(literal, labels[1], "input unchanged")
  t.assert_eq("42", snapshot:annotations({ 42 })[1], "existing numeric coercion")
  t.assert_eq(literal, snapshot:annotations({ [1] = literal, [3] = "ignored after hole" })[2], "array prefix")

  for _, bad in ipairs({ {}, { "extra", "label" }, { [2] = "hole" }, { false }, { {} } }) do
    t.assert_false(pcall(snapshot.annotations, snapshot, bad), "invalid labels rejected")
  end
  local oversized = {}
  for index = 1, 12000 do
    oversized[index] = "label " .. index
  end
  local ok, error_text = pcall(snapshot.annotations, snapshot, oversized)
  t.assert_false(ok, "oversized labels rejected")
  t.assert_true(tostring(error_text):find("must match", 1, true) ~= nil, "count error, not native panic")
  t.assert_eq(literal, snapshot:annotations({ literal })[1], "usable after errors")

  state, snapshot, err = query("file", "")
  t.assert_eq("completed", state, err)
  t.assert_true(vim.deep_equal({}, snapshot:annotations({})), "empty snapshot")
  t.assert_true(vim.deep_equal({}, snapshot:annotations({ [2] = "after empty prefix" })), "empty prefix contract")
end)

t:test("annotation projection supports 10k distinct commits without exhausting Lua references", function()
  workspace = vim.fn.tempname()
  vim.fn.mkdir(workspace, "p")
  local root = workspace
  t:defer(function()
    vim.fn.delete(root, "rf")
  end)
  local content = require("__test__.fixtures.era.m.git.blame_history").build(root, 10000, 1)
  local state, snapshot, err = query("file", content, 20000)
  t.assert_eq("completed", state, err)
  local lines, commits = snapshot:stats()
  t.assert_eq(10000, lines, "line count")
  t.assert_eq(10000, commits, "distinct leaf commits")
  local labels = {}
  for index, commit in ipairs(snapshot:commits()) do
    labels[index] = "label " .. assert(commit.summary:match("^leaf (%d+)$")) .. "\0\255%1<sha>"
  end
  local annotations = snapshot:annotations(labels)
  t.assert_eq(lines, #annotations, "full annotation count")
  for lnum, text in ipairs(annotations) do
    t.assert_eq("label " .. lnum .. "\0\255%1<sha>", text, "line-to-commit mapping")
  end
  t.assert_eq("leaf 1", snapshot:commit_at(1).summary, "snapshot remains usable")
end)

t:run()
