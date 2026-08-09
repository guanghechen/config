---@diagnostic disable: undefined-global, missing-fields
--- Run with: nvim -l lua/__test__/era/m/diffview/data_numstat.lua

local bootstrap = require("__test__.bootstrap")
local CancellationToken = require("stl.c.cancellation_token")
local harness = require("__test__.harness")

local t = harness.new("era.m.diffview.data_numstat")

bootstrap.with_global(t, "stl", { env = { IS_WIN = false } })
bootstrap.with_global(t, "dot", {})
bootstrap.with_global(t, "era", {})

local data = assert(loadfile("lua/era/m/diffview/data.lua"))()

---@param repo                          string
---@param ...                           string
---@return vim.SystemCompleted
local function git(repo, ...)
  return vim.system({ "git", "-C", repo, ... }, { text = true }):wait()
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

t:test("numstat: requests NUL-delimited staged and unstaged data without requiring HEAD", function()
  local commands = {} ---@type string[][]
  local command_opts = {} ---@type stl.git.exec.IExecOpts[]
  stl.git = {
    exec = {
      exec = function(args, opts)
        commands[#commands + 1] = args
        command_opts[#command_opts + 1] = opts
        return { code = 0, lines = {} }
      end,
    },
  }
  stl.async = {
    await_all = function(futures)
      return futures
    end,
  }
  dot.path = {
    workspace = function()
      return "/repo"
    end,
  }

  data.__fetch_numstat__({ { filepath = "a.lua", stage_type = "staged", status = "A" } })

  t.assert_eq("diff --staged --numstat -z --", table.concat(commands[1], " "), "staged command")
  t.assert_eq("diff --numstat -z --", table.concat(commands[2], " "), "unstaged command")
  t.assert_true(command_opts[1].raw, "staged raw output")
  t.assert_true(command_opts[2].raw, "unstaged raw output")
end)

t:test("numstat: batches all untracked files through one isolated index", function()
  local commands = {} ---@type string[][]
  local command_opts = {} ---@type stl.git.exec.IExecOpts[]
  stl.git = {
    exec = {
      exec = function(args, opts)
        commands[#commands + 1] = args
        command_opts[#command_opts + 1] = opts
        if #commands == 5 then
          return { code = 0, lines = { "3\t0\tnew.lua\0" }, stderr = "" }
        end
        return { code = 0, lines = {}, stderr = "" }
      end,
    },
  }
  stl.async = {
    await_all = function(futures)
      return futures
    end,
  }
  dot.path = {
    workspace = function()
      return "/repo"
    end,
  }
  local entries = {} ---@type era.m.diffview.IFileEntry[]
  for index = 1, 100 do
    entries[index] =
      { filepath = index == 1 and "new.lua" or ("bulk/" .. index), stage_type = "unstaged", status = "?" }
  end

  data.__fetch_numstat__(entries)

  t.assert_eq(5, #commands, "fixed Git process count")
  t.assert_eq("read-tree --empty", table.concat(commands[3], " "), "temporary index command")
  t.assert_eq(
    "--literal-pathspecs add -N --pathspec-from-file=- --pathspec-file-nul",
    table.concat(commands[4], " "),
    "intent-to-add command"
  )
  t.assert_eq("diff --numstat -z --", table.concat(commands[5], " "), "untracked diff command")
  t.assert_eq(command_opts[3].env.GIT_INDEX_FILE, command_opts[5].env.GIT_INDEX_FILE, "isolated index reused")
  t.assert_true(command_opts[3].env.GIT_INDEX_FILE ~= "/repo/.git/index", "main index untouched")
  t.assert_true(command_opts[4].stdin:sub(1, 8) == "new.lua\0", "NUL pathspec stdin")
  t.assert_true(command_opts[5].raw, "raw output")
  t.assert_eq(3, entries[1].insertions, "untracked insertions")
  t.assert_eq(0, entries[1].deletions, "untracked deletions")
end)

t:test("numstat: rejects staged and unstaged query failures", function()
  dot.path = {
    workspace = function()
      return "/repo"
    end,
  }
  stl.async = {
    await_all = function(futures)
      return futures
    end,
  }

  local function assert_failure(responses, expected)
    local index = 0 ---@type integer
    stl.git = {
      exec = {
        exec = function()
          index = index + 1
          return responses[index]
        end,
      },
    }

    local ok, err = pcall(data.__fetch_numstat__, { { filepath = "a.lua", stage_type = "staged", status = "M" } })
    t.assert_false(ok, "failed query rejected")
    t.assert_true(tostring(err):find(expected, 1, true) ~= nil, "actionable query failure")
  end

  assert_failure({
    { code = 128, lines = {}, stderr = "fatal: staged failed\n" },
    { code = 0, lines = {}, stderr = "" },
  }, "numstat staged diff failed (exit 128): fatal: staged failed")
  assert_failure({
    { code = 0, lines = {}, stderr = "" },
    { code = 1, lines = {}, stderr = "fatal: unstaged failed\n" },
  }, "numstat unstaged diff failed (exit 1): fatal: unstaged failed")
end)

t:test("numstat: degrades an untracked temporary-index query failure", function()
  local responses = {
    { code = 0, lines = { "7\t2\tstaged.lua\0" }, stderr = "" },
    { code = 0, lines = { "3\t1\tmodified.lua\0" }, stderr = "" },
    { code = 0, lines = {}, stderr = "" },
    { code = 0, lines = {}, stderr = "" },
    { code = 128, lines = {}, stderr = "fatal: cannot hash unreadable.lua\n" },
  }
  local index = 0 ---@type integer
  stl.git = {
    exec = {
      exec = function()
        index = index + 1
        return responses[index]
      end,
    },
  }
  stl.async = {
    await_all = function(futures)
      return futures
    end,
  }
  dot.path = {
    workspace = function()
      return "/repo"
    end,
  }

  local staged = { filepath = "staged.lua", stage_type = "staged", status = "M" }
  local modified = { filepath = "modified.lua", stage_type = "unstaged", status = "M" }
  local untracked = { filepath = "unreadable.lua", stage_type = "unstaged", status = "?" }
  local result = data.__fetch_numstat__({ staged, modified, untracked })

  t.assert_true(result[1] == staged and result[2] == modified and result[3] == untracked, "entries preserved")
  t.assert_eq(7, staged.insertions, "staged stats preserved")
  t.assert_eq(2, staged.deletions, "staged deletions preserved")
  t.assert_eq(3, modified.insertions, "unstaged stats preserved")
  t.assert_eq(1, modified.deletions, "unstaged deletions preserved")
  t.assert_nil(untracked.insertions, "failed untracked insertions remain unknown")
  t.assert_nil(untracked.deletions, "failed untracked deletions remain unknown")
end)

t:test("numstat: cancellation stops the isolated-index pipeline and removes its temp directory", function()
  local command_count = 0 ---@type integer
  local temp_index = nil ---@type string|nil
  local token = CancellationToken.new()
  stl.git = {
    exec = {
      exec = function(_, opts, exec_token)
        command_count = command_count + 1
        if command_count == 3 then
          temp_index = opts.env.GIT_INDEX_FILE
          exec_token:cancel()
          return { code = -1, lines = {}, stderr = "Operation cancelled" }
        end
        return { code = 0, lines = {}, stderr = "" }
      end,
    },
  }
  stl.async = {
    await_all = function(futures)
      return futures
    end,
  }
  dot.path = {
    workspace = function()
      return "/repo"
    end,
  }

  local ok = pcall(data.__fetch_numstat__, {
    { filepath = "new.lua", stage_type = "unstaged", status = "?" },
  }, token)

  t.assert_false(ok, "cancelled query rejected")
  t.assert_eq(3, command_count, "later temporary-index commands skipped")
  local temp_dir = assert(temp_index):match("^(.*)/index$")
  t.assert_true(temp_dir ~= nil and vim.uv.fs_stat(temp_dir) == nil, "temporary index removed")
end)

t:test("numstat: unexpected temporary-index errors propagate after cleanup", function()
  local command_count = 0 ---@type integer
  local temp_index = nil ---@type string|nil
  stl.git = {
    exec = {
      exec = function(_, opts)
        command_count = command_count + 1
        if command_count == 3 then
          temp_index = opts.env.GIT_INDEX_FILE
          error("unexpected executor bug")
        end
        return { code = 0, lines = {}, stderr = "" }
      end,
    },
  }
  stl.async = {
    await_all = function(futures)
      return futures
    end,
  }
  dot.path = {
    workspace = function()
      return "/repo"
    end,
  }

  local ok, err = pcall(data.__fetch_numstat__, {
    { filepath = "new.lua", stage_type = "unstaged", status = "?" },
  })

  t.assert_false(ok, "unexpected error propagated")
  t.assert_true(tostring(err):find("unexpected executor bug", 1, true) ~= nil, "original error preserved")
  local temp_dir = assert(temp_index):match("^(.*)/index$")
  t.assert_true(temp_dir ~= nil and vim.uv.fs_stat(temp_dir) == nil, "temporary index removed")
end)

t:test("status conversion keeps stage-specific rename sources", function()
  local entries = data.__convert_status_to_entries__({
    ["/repo/new.lua"] = {
      relative = "new.lua",
      stage = "mixed",
      staged = { R = true },
      unstaged = { R = true },
      staged_prev_relative = "head.lua",
      unstaged_prev_relative = "index.lua",
    },
  })

  local sources = {} ---@type table<string, string>
  for _, entry in ipairs(entries) do
    sources[assert(entry.stage_type)] = assert(entry.prev_filepath)
  end
  t.assert_eq("head.lua", sources.staged, "staged source")
  t.assert_eq("index.lua", sources.unstaged, "unstaged source")

  local staged_only = data.__convert_status_to_entries__({
    ["/repo/plain.lua"] = {
      relative = "plain.lua",
      stage = "mixed",
      staged = { M = true },
      unstaged = { R = true },
      unstaged_prev_relative = "index.lua",
    },
  })
  for _, entry in ipairs(staged_only) do
    if entry.stage_type == "staged" then
      t.assert_nil(entry.prev_filepath, "staged source does not fall through")
    end
  end
end)

t:test("status conversion keeps staged deletion and same-path untracked replacement", function()
  local entries = data.__convert_status_to_entries__({
    ["/repo/replaced.lua"] = {
      relative = "replaced.lua",
      stage = "staged",
      staged = { D = true },
      unstaged = { ["?"] = true },
      codes = { D = true, ["?"] = true },
    },
  })

  local statuses = {} ---@type table<string, string>
  for _, entry in ipairs(entries) do
    statuses[assert(entry.stage_type)] = entry.status
  end

  t.assert_eq(2, #entries, "independent stage entries")
  t.assert_eq("D", statuses.staged, "staged deletion")
  t.assert_eq("?", statuses.unstaged, "unstaged replacement")
end)

t:test("numstat: consumes Git's real NUL-delimited rename format", function()
  local repo = vim.fn.tempname() ---@type string
  vim.fn.mkdir(repo .. "/src", "p")

  local ok, err = xpcall(function()
    t.assert_eq(0, git(repo, "init", "-q").code, "git init")

    local original = {} ---@type string[]
    for index = 1, 20 do
      original[index] = "line " .. index
    end
    vim.fn.writefile(original, repo .. "/src/old.lua")
    t.assert_eq(0, git(repo, "add", "--", "src/old.lua").code, "initial add")
    t.assert_eq(
      0,
      git(repo, "-c", "user.name=Test", "-c", "user.email=test@example.com", "commit", "-qm", "base").code,
      "initial commit"
    )

    t.assert_eq(0, git(repo, "mv", "src/old.lua", "src/new.lua").code, "git mv")
    vim.fn.writefile({ "added one", "added two" }, repo .. "/src/new.lua", "a")
    t.assert_eq(0, git(repo, "add", "--", "src/new.lua").code, "stage rename")

    local result = git(repo, "diff", "--staged", "--numstat", "-z", "--")
    t.assert_eq(0, result.code, "numstat")
    local lines = vim.split(result.stdout or "", "\n", { plain = true })
    if lines[#lines] == "" then
      lines[#lines] = nil
    end

    local renamed = { filepath = "src/new.lua", stage_type = "staged", status = "R" }
    data.__apply_numstat_stats__({ renamed }, { code = result.code, lines = lines }, "staged")

    t.assert_eq(2, renamed.insertions, "rename insertions")
    t.assert_eq(0, renamed.deletions, "rename deletions")
  end, debug.traceback)

  vim.fn.delete(repo, "rf")
  if not ok then
    error(err)
  end
end)

t:test("numstat: reads real untracked text while preserving binary and empty semantics", function()
  local repo = vim.fn.tempname() ---@type string
  vim.fn.mkdir(repo, "p")

  local ok, err = xpcall(function()
    t.assert_eq(0, git(repo, "init", "-q").code, "git init")
    vim.fn.writefile({ "one", "two", "three" }, repo .. "/plain.txt")
    vim.fn.writefile({}, repo .. "/empty.txt")
    local special = "tab\tand\nnewline.txt" ---@type string
    vim.fn.writefile({ "one", "two" }, repo .. "/" .. special)
    local magic = ":(glob)o*.txt" ---@type string
    vim.fn.writefile({ "magic", "only" }, repo .. "/" .. magic)
    vim.fn.writefile({ "other" }, repo .. "/other.txt")
    local binary = assert(io.open(repo .. "/binary.dat", "wb"))
    binary:write("before\0after")
    binary:close()

    stl.git = {
      exec = {
        exec = function(args, opts)
          local cmd = { "git", "-C", opts.cwd }
          vim.list_extend(cmd, args)
          local result = vim.system(cmd, { env = opts.env, stdin = opts.stdin, text = false }):wait()
          return {
            code = result.code,
            lines = result.code == 0 and result.stdout ~= "" and { result.stdout } or {},
            stderr = result.stderr or "",
          }
        end,
      },
    }
    stl.async = {
      await_all = function(futures)
        return futures
      end,
    }
    dot.path = {
      workspace = function()
        return repo
      end,
    }

    local plain = { filepath = "plain.txt", stage_type = "unstaged", status = "?" }
    local empty = { filepath = "empty.txt", stage_type = "unstaged", status = "?" }
    local binary_entry = { filepath = "binary.dat", stage_type = "unstaged", status = "?" }
    local special_entry = { filepath = special, stage_type = "unstaged", status = "?" }
    local magic_entry = { filepath = magic, stage_type = "unstaged", status = "?" }
    local other_entry = { filepath = "other.txt", stage_type = "unstaged", status = "?" }
    data.__fetch_numstat__({ plain, empty, binary_entry, special_entry, magic_entry, other_entry })

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
  end, debug.traceback)

  vim.fn.delete(repo, "rf")
  if not ok then
    error(err)
  end
end)

t:test("numstat: an unreadable untracked file does not block the Changes snapshot", function()
  local repo = vim.fn.tempname() ---@type string
  vim.fn.mkdir(repo, "p")
  local unreadable = repo .. "/unreadable.txt" ---@type string

  local ok, err = xpcall(function()
    t.assert_eq(0, git(repo, "init", "-q").code, "git init")
    vim.fn.writefile({ "cannot read this" }, unreadable)
    t.assert_true(vim.uv.fs_chmod(unreadable, 0) == true, "make fixture unreadable")

    stl.git = {
      exec = {
        exec = function(args, opts)
          local cmd = { "git", "-C", opts.cwd }
          vim.list_extend(cmd, args)
          local result = vim.system(cmd, { env = opts.env, stdin = opts.stdin, text = false }):wait()
          return {
            code = result.code,
            lines = result.code == 0 and result.stdout ~= "" and { result.stdout } or {},
            stderr = result.stderr or "",
          }
        end,
      },
    }
    stl.async = {
      await_all = function(futures)
        return futures
      end,
    }
    dot.path = {
      workspace = function()
        return repo
      end,
    }

    local entry = { filepath = "unreadable.txt", stage_type = "unstaged", status = "?" }
    local result = data.__fetch_numstat__({ entry })

    t.assert_true(result[1] == entry, "entry preserved")
    t.assert_nil(entry.insertions, "insertions remain unknown")
    t.assert_nil(entry.deletions, "deletions remain unknown")
  end, debug.traceback)

  vim.uv.fs_chmod(unreadable, 384)
  vim.fn.delete(repo, "rf")
  if not ok then
    error(err)
  end
end)

t:run()
