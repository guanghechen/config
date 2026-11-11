local bootstrap = require("__test__.support.bootstrap")
local CancellationToken = require("stl.c.cancellation_token")
local harness = require("__test__.support.harness")

local t = harness.new()
local fs = require("__test__.support.fs")
local git = require("__test__.support.git")

bootstrap.with_global(t, "stl", { env = { IS_WIN = false } })
bootstrap.with_global(t, "dot", {})
bootstrap.with_global(t, "era", {})

local data = require("era.m.diffview.data")

---Runs Git commands through `exec`, with awaited futures returned as they are, in the workspace `root` for the rest of
---the case.
---@param exec                          fun(args: string[], opts: stl.git.exec.IExecOpts, token: any): stl.git.exec.IResult
---@param root                          string
---@return nil
local function use_git(exec, root)
  t:patch_table(stl, "git", { exec = { exec = exec } })
  t:patch_table(stl, "async", {
    await_all = function(futures)
      return futures
    end,
  })
  t:patch_table(dot, "path", {
    workspace = function()
      return root
    end,
  })
end

---Runs a Git command as a real process.
---@param args                          string[]
---@param opts                          stl.git.exec.IExecOpts
---@return stl.git.exec.IResult
local function real_exec(args, opts)
  local cmd = { "git", "-C", opts.cwd }
  vim.list_extend(cmd, args)
  local result = vim.system(cmd, { env = opts.env, stdin = opts.stdin, text = false }):wait()
  return {
    code = result.code,
    lines = result.code == 0 and result.stdout ~= "" and { result.stdout } or {},
    stderr = result.stderr or "",
  }
end

t:test("numstat: parses NUL-delimited normal and rename records", function()
  local normal = { filepath = "src/foo.lua", stage_type = "staged", status = "M" }
  local renamed = { filepath = "src/new.lua", stage_type = "staged", status = "R" }
  local binary = { filepath = "asset.bin", stage_type = "staged", status = "M" }
  local output = "12\t3\tsrc/foo.lua\0" .. "4\t5\t\0src/old.lua\0src/new.lua\0" .. "-\t-\tasset.bin\0"

  data.__apply_numstat_stats__({ normal, renamed, binary }, { code = 0, lines = { output } }, "staged")

  t.assert_eq(12, normal.insertions, "normal insertions")
  t.assert_eq(3, normal.deletions, "normal deletions")
  t.assert_eq(4, renamed.insertions, "rename insertions")
  t.assert_eq(5, renamed.deletions, "rename deletions")
  t.assert_nil(binary.insertions, "binary insertions")
  t.assert_nil(binary.deletions, "binary deletions")
end)

t:test("numstat: applies stats only to the requested stage", function()
  local staged = { filepath = "same.lua", stage_type = "staged", status = "M" }
  local unstaged = { filepath = "same.lua", stage_type = "unstaged", status = "M" }

  data.__apply_numstat_stats__({ staged, unstaged }, { code = 0, lines = { "7\t2\tsame.lua\0" } }, "staged")

  t.assert_eq(7, staged.insertions, "staged insertions")
  t.assert_eq(2, staged.deletions, "staged deletions")
  t.assert_nil(unstaged.insertions, "unstaged insertions")
  t.assert_nil(unstaged.deletions, "unstaged deletions")
end)

t:test("numstat: preserves literal special paths from the NUL protocol", function()
  local tabbed = { filepath = "tab\tname.lua", stage_type = "staged", status = "A" }
  local multiline = { filepath = "multi\nline.lua", stage_type = "staged", status = "A" }
  local output = "3\t1\ttab\tname.lua\0" .. "4\t2\tmulti\nline.lua\0"

  data.__apply_numstat_stats__({ tabbed, multiline }, { code = 0, lines = vim.split(output, "\n") }, "staged")

  t.assert_eq(3, tabbed.insertions, "tab path insertions")
  t.assert_eq(1, tabbed.deletions, "tab path deletions")
  t.assert_eq(4, multiline.insertions, "newline path insertions")
  t.assert_eq(2, multiline.deletions, "newline path deletions")
end)

t:test("numstat: batches all untracked files through one isolated index", function()
  local commands = {} ---@type string[][]
  local command_opts = {} ---@type stl.git.exec.IExecOpts[]
  use_git(function(args, opts)
    commands[#commands + 1] = args
    command_opts[#command_opts + 1] = opts
    if #commands == 2 then
      return { code = 0, lines = { "3\t0\tnew.lua\0" }, stderr = "" }
    end
    return { code = 0, lines = {}, stderr = "" }
  end, "/repo")
  local entries = {} ---@type era.m.diffview.IFileEntry[]
  for index = 1, 100 do
    entries[index] =
      { filepath = index == 1 and "new.lua" or ("bulk/" .. index), stage_type = "unstaged", status = "?" }
  end

  data.__fetch_untracked_numstat__(entries)

  t.assert_eq(2, #commands, "fixed Git process count")
  t.assert_eq(
    "--literal-pathspecs add -N --pathspec-from-file=- --pathspec-file-nul",
    table.concat(commands[1], " "),
    "intent-to-add command"
  )
  t.assert_eq("diff --numstat -z --", table.concat(commands[2], " "), "untracked diff command")
  t.assert_eq(command_opts[1].env.GIT_INDEX_FILE, command_opts[2].env.GIT_INDEX_FILE, "isolated index reused")
  t.assert_true(command_opts[1].env.GIT_INDEX_FILE ~= "/repo/.git/index", "main index untouched")
  t.assert_true(command_opts[1].stdin:sub(1, 8) == "new.lua\0", "NUL pathspec stdin")
  t.assert_true(command_opts[2].raw, "raw output")
  t.assert_eq(3, entries[1].insertions, "untracked insertions")
  t.assert_eq(0, entries[1].deletions, "untracked deletions")
end)

t:test("numstat: degrades an untracked temporary-index query failure", function()
  local responses = {
    { code = 0, lines = {}, stderr = "" },
    { code = 128, lines = {}, stderr = "fatal: cannot hash unreadable.lua\n" },
  }
  local index = 0 ---@type integer
  use_git(function()
    index = index + 1
    return responses[index]
  end, "/repo")

  local staged = { filepath = "staged.lua", stage_type = "staged", status = "M", insertions = 7, deletions = 2 }
  local modified = { filepath = "modified.lua", stage_type = "unstaged", status = "M", insertions = 3, deletions = 1 }
  local untracked = { filepath = "unreadable.lua", stage_type = "unstaged", status = "?" }
  local result = data.__fetch_untracked_numstat__({ staged, modified, untracked })

  t.assert_true(result[1] == staged and result[2] == modified and result[3] == untracked, "entries preserved")
  t.assert_eq(7, staged.insertions, "staged stats preserved")
  t.assert_eq(2, staged.deletions, "staged deletions preserved")
  t.assert_eq(3, modified.insertions, "unstaged stats preserved")
  t.assert_eq(1, modified.deletions, "unstaged deletions preserved")
  t.assert_nil(untracked.insertions, "failed untracked insertions remain unknown")
  t.assert_nil(untracked.deletions, "failed untracked deletions remain unknown")
end)

for _, case in ipairs({
  {
    name = "numstat: cancellation stops the isolated-index pipeline and removes its temp directory",
    token = true,
    -- The query is cancelled while its first command runs.
    fail = function(exec_token)
      exec_token:cancel()
      return { code = -1, lines = {}, stderr = "Operation cancelled" }
    end,
  },
  {
    name = "numstat: unexpected temporary-index errors propagate after cleanup",
    fail = function()
      error("unexpected executor bug")
    end,
    error = "unexpected executor bug",
  },
}) do
  t:test(case.name, function()
    local command_count = 0 ---@type integer
    local temp_index = nil ---@type string|nil
    use_git(function(_, opts, exec_token)
      command_count = command_count + 1
      if command_count == 1 then
        temp_index = opts.env.GIT_INDEX_FILE
        return case.fail(exec_token)
      end
      return { code = 0, lines = {}, stderr = "" }
    end, "/repo")

    local token = case.token and CancellationToken.new() or nil
    local ok, err = pcall(data.__fetch_untracked_numstat__, {
      { filepath = "new.lua", stage_type = "unstaged", status = "?" },
    }, token)

    t.assert_false(ok, "query rejected")
    if case.error then
      t.assert_true(tostring(err):find(case.error, 1, true) ~= nil, "the unexpected error propagates as it was raised")
    end
    t.assert_eq(1, command_count, "later temporary-index commands skipped")
    local temp_dir = assert(temp_index):match("^(.*)/index$")
    t.assert_true(temp_dir ~= nil and vim.uv.fs_stat(temp_dir) == nil, "temporary index removed")
  end)
end

t:test("numstat: consumes Git's real NUL-delimited rename format", function()
  local repo = git.repo(t)
  local original = {} ---@type string[]
  for index = 1, 20 do
    original[index] = "line " .. index
  end
  fs.write(repo .. "/src/old.lua", original)
  git.commit(repo, "base")

  git.run(repo, { "mv", "src/old.lua", "src/new.lua" })
  vim.fn.writefile({ "added one", "added two" }, repo .. "/src/new.lua", "a")
  git.run(repo, { "add", "--", "src/new.lua" })

  local result = git.system(repo, { "diff", "--staged", "--numstat", "-z", "--" })
  t.assert_eq(0, result.code, "numstat")
  local lines = vim.split(result.stdout or "", "\n", { plain = true })
  if lines[#lines] == "" then
    lines[#lines] = nil
  end

  local renamed = { filepath = "src/new.lua", stage_type = "staged", status = "R" }
  data.__apply_numstat_stats__({ renamed }, { code = result.code, lines = lines }, "staged")

  t.assert_eq(2, renamed.insertions, "rename insertions")
  t.assert_eq(0, renamed.deletions, "rename deletions")
end)

t:test("numstat: reads real untracked text while preserving binary and empty semantics", function()
  local repo = git.repo(t)
  fs.write(repo .. "/plain.txt", { "one", "two", "three" })
  fs.write(repo .. "/empty.txt", {})
  local special = "tab\tand\nnewline.txt" ---@type string
  fs.write(repo .. "/" .. special, { "one", "two" })
  local magic = ":(glob)o*.txt" ---@type string
  fs.write(repo .. "/" .. magic, { "magic", "only" })
  fs.write(repo .. "/other.txt", { "other" })
  fs.write(repo .. "/binary.dat", "before\0after")

  use_git(real_exec, repo)

  local plain = { filepath = "plain.txt", stage_type = "unstaged", status = "?" }
  local empty = { filepath = "empty.txt", stage_type = "unstaged", status = "?" }
  local binary_entry = { filepath = "binary.dat", stage_type = "unstaged", status = "?" }
  local special_entry = { filepath = special, stage_type = "unstaged", status = "?" }
  local magic_entry = { filepath = magic, stage_type = "unstaged", status = "?" }
  local other_entry = { filepath = "other.txt", stage_type = "unstaged", status = "?" }
  data.__fetch_untracked_numstat__({ plain, empty, binary_entry, special_entry, magic_entry, other_entry })

  t.assert_eq(3, plain.insertions, "text insertions")
  t.assert_eq(0, plain.deletions, "text deletions")
  t.assert_eq(0, empty.insertions, "empty insertions")
  t.assert_eq(0, empty.deletions, "empty deletions")
  t.assert_nil(binary_entry.insertions, "binary insertions")
  t.assert_nil(binary_entry.deletions, "binary deletions")
  t.assert_eq(2, special_entry.insertions, "special-path insertions")
  t.assert_eq(0, special_entry.deletions, "special-path deletions")
  t.assert_eq(2, magic_entry.insertions, "pathspec-magic filename insertions")
  t.assert_eq(0, magic_entry.deletions, "pathspec-magic filename deletions")
  t.assert_eq(1, other_entry.insertions, "glob target remains independent")
  t.assert_eq(0, other_entry.deletions, "glob target deletions")
end)

t:test("numstat: an unreadable untracked file does not block the Changes snapshot", function()
  local repo = git.repo(t)
  local unreadable = repo .. "/unreadable.txt" ---@type string
  t:defer(function()
    vim.uv.fs_chmod(unreadable, 384)
  end)
  vim.fn.writefile({ "cannot read this" }, unreadable)
  t.assert_true(vim.uv.fs_chmod(unreadable, 0) == true, "make fixture unreadable")

  use_git(real_exec, repo)

  local entry = { filepath = "unreadable.txt", stage_type = "unstaged", status = "?" }
  local result = data.__fetch_untracked_numstat__({ entry })

  t.assert_true(result[1] == entry, "entry preserved")
  t.assert_nil(entry.insertions, "insertions remain unknown")
  t.assert_nil(entry.deletions, "deletions remain unknown")
end)

t:run()
