--- Run with: nvim -l __test__/run.lua __test__/specs/era/m/git/status_snapshot_spec.lua
---@diagnostic disable: undefined-global

local bootstrap = require("__test__.support.bootstrap")
local harness = require("__test__.support.harness")
local git_exec = require("stl.git.exec")

local t = harness.new("era.m.git.status_snapshot")
local workspace = "" ---@type string

bootstrap.with_stl_c(t)
bootstrap.with_runtime(t, {
  stl = {
    async = require("stl.async"),
    env = { PATH_SEP = package.config:sub(1, 1) },
    git = {
      exec = {
        exec = function(args, opts, token)
          return git_exec.exec(args, opts, token)
        end,
      },
    },
  },
  yoz = require("yoz"),
  dot = {
    path = {
      workspace = function()
        return workspace
      end,
      is_git_repo = function()
        return true
      end,
    },
  },
})

local status = require("era.m.git.status")
local reference = assert(loadfile("__test__/fixtures/era/m/git/status_lua_reference.lua"))()

---@param cwd                           string
---@param args                          string[]
---@param stdin                         ?string
---@return string
local function git(cwd, args, stdin)
  local command = { "git", "-C", cwd, "-c", "commit.gpgSign=false" }
  vim.list_extend(command, args)
  local result = vim.system(command, { stdin = stdin, text = false }):wait()
  t.assert_eq(0, result.code, result.stderr)
  return result.stdout or ""
end

---@param cwd                           string
---@return nil
local function commit(cwd)
  git(cwd, { "-c", "user.name=Test", "-c", "user.email=test@example.com", "commit", "-qm", "fixture" })
end

---@param object_format                 ?string
---@return string
local function new_repo(object_format)
  local root = vim.fn.tempname() ---@type string
  vim.fn.mkdir(root, "p")
  t:defer(function()
    vim.fn.delete(root, "rf")
  end)
  local args = { "init", "-q" }
  if object_format then
    args[#args + 1] = "--object-format=" .. object_format
  end
  git(root, args)
  workspace = root
  return root
end

---@param opts                          ?era.m.git.status.ICollectOpts
---@return yoz.git.StatusSnapshot
local function collect(opts)
  local future = status.collect(opts)
  t.wait_until(function()
    return future:is_done()
  end, 10000, "Git status did not finish")
  t.assert_false(future:is_failed(), future:get_error())
  return assert(future:get_result())
end

---@param processes                     integer
---@param include_untracked             ?boolean
---@return era.m.git.status.ICollectResult
local function assert_snapshot_parity(processes, include_untracked)
  local snapshot = collect({ include_untracked = include_untracked })
  t.assert_eq(processes, snapshot:stats(), "default snapshot process count")
  local current = snapshot:export()
  local future = reference.collect({ include_numstat = true, include_untracked = include_untracked })
  t.wait_until(function()
    return future:is_done()
  end, 10000, "Lua oracle timed out")
  t.assert_false(future:is_failed(), future:get_error())
  local raw = future:get_result()
  t.assert_true(vim.deep_equal(raw.status_map, current.status_map), "raw and porcelain status maps differ")
  t.assert_true(vim.deep_equal(raw.status_groups, current.status_groups), "raw and porcelain status groups differ")
  local numbered = collect({ include_numstat = true, include_untracked = include_untracked }):export()
  t.assert_true(vim.deep_equal(raw, numbered), "native and Lua numstat snapshots differ")
  local aggregated = reference.aggregate(raw.status_map)
  t:patch_global("era", {
    m = {
      git = {
        state = {
          snapshot = function()
            return snapshot
          end,
          aggregated = function()
            return aggregated
          end,
        },
      },
    },
  })
  for path, entry in pairs(raw.status_map) do
    local paths = { path }
    if entry.codes["?"] then
      paths[#paths + 1] = path .. "/descendant"
    end
    for _, query in ipairs(paths) do
      for _, kind in ipairs({ "file", "directory" }) do
        local expected_hl, actual_hl = {}, {}
        local expected, expected_name_hl = reference.calc_info(query, kind, 3, expected_hl)
        local actual, actual_name_hl = status.calc_info(query, kind, 3, actual_hl)
        t.assert_eq(expected, actual, "status text parity")
        t.assert_eq(expected_name_hl, actual_name_hl, "status name highlight parity")
        t.assert_true(vim.deep_equal(expected_hl, actual_hl), "status segment highlight parity")
      end
    end
  end
  return current
end

t:test("ordinary snapshots use one query and preserve mixed changes and deletions", function()
  local root = new_repo()
  for _, name in ipairs({ "mixed", "modified", "deleted", "staged-delete" }) do
    vim.fn.writefile({ name }, root .. "/" .. name)
  end
  git(root, { "add", "." })
  commit(root)
  vim.fn.writefile({ "staged" }, root .. "/mixed", "a")
  git(root, { "add", "mixed" })
  vim.fn.writefile({ "unstaged" }, root .. "/mixed", "a")
  vim.fn.writefile({ "modified" }, root .. "/modified", "a")
  assert(vim.uv.fs_unlink(root .. "/deleted"))
  git(root, { "rm", "staged-delete" })
  vim.fn.writefile({ "new" }, root .. "/untracked")

  local result = assert_snapshot_parity(1)
  t.assert_eq("mixed", result.status_map[root .. "/mixed"].stage, "mixed change")
  t.assert_true(result.status_map[root .. "/deleted"].unstaged.D, "worktree deletion")
  t.assert_true(result.status_map[root .. "/staged-delete"].staged.D, "staged deletion")
end)

t:test("snapshot preserves full SHA-256 object identities", function()
  local root = new_repo("sha256")
  vim.fn.writefile({ "base" }, root .. "/file")
  git(root, { "add", "file" })
  commit(root)
  local old_object = git(root, { "rev-parse", "HEAD:file" }):gsub("\n$", "")
  vim.fn.writefile({ "staged" }, root .. "/file", "a")
  git(root, { "add", "file" })
  local new_object = git(root, { "rev-parse", ":file" }):gsub("\n$", "")
  vim.fn.writefile({ "unstaged" }, root .. "/file", "a")

  local entry = assert_snapshot_parity(1).status_map[root .. "/file"]
  t.assert_eq(64, #old_object, "SHA-256 repository")
  t.assert_eq(old_object, entry.staged_old_object_name, "full HEAD identity")
  t.assert_eq(new_object, entry.staged_new_object_name, "full staged identity")
  t.assert_eq(new_object, entry.unstaged_old_object_name, "full unstaged base identity")
end)

t:test("snapshot and Lua exports preserve native pathname bytes", function()
  local root = new_repo()
  -- Windows requires Unicode filenames; Unix also permits invalid UTF-8 bytes.
  local suffix = package.config:sub(1, 1) == "/" and "\255" or "字"
  local directory = root .. "/raw-" .. suffix
  assert(vim.uv.fs_mkdir(directory, 493))
  local path = directory .. "/file-" .. suffix
  vim.fn.writefile({ "base" }, path)
  git(root, { "add", "." })
  commit(root)
  vim.fn.writefile({ "changed" }, path, "a")

  local result = assert_snapshot_parity(1)
  t.assert_eq(path, result.status_map[path].path, "exported pathname bytes")
  t.assert_eq("M", collect():lookup(directory, true).display, "native directory lookup")
end)

t:test("snapshot preserves mixed changes, renames, deletes, and literal pathnames", function()
  local root = new_repo()
  for _, name in ipairs({ "source", "mixed", "deleted", "recreated" }) do
    vim.fn.writefile({ name }, root .. "/" .. name)
  end
  git(root, { "add", "." })
  commit(root)
  git(root, { "mv", "source", "renamed\tfile" })
  vim.fn.writefile({ "staged" }, root .. "/mixed", "a")
  git(root, { "add", "mixed" })
  vim.fn.writefile({ "unstaged" }, root .. "/mixed", "a")
  vim.fn.writefile({ "renamed and edited" }, root .. "/renamed\tfile", "a")
  assert(vim.uv.fs_unlink(root .. "/deleted"))
  git(root, { "rm", "recreated" })
  vim.fn.writefile({ "new content" }, root .. "/recreated")
  vim.fn.writefile({ "fresh" }, root .. "/space name")
  vim.fn.writefile({ "fresh" }, root .. "/line\nbreak")

  local result = assert_snapshot_parity(3)
  t.assert_eq("mixed", result.status_map[root .. "/mixed"].stage, "mixed state")
  t.assert_eq("source", result.status_map[root .. "/renamed\tfile"].staged_prev_relative, "rename source")
  t.assert_true(result.status_map[root .. "/recreated"].staged.D, "staged deletion")
  t.assert_true(result.status_map[root .. "/recreated"].unstaged["?"], "recreated untracked file")
  result = assert_snapshot_parity(3, false)
  t.assert_nil(result.status_map[root .. "/space name"], "untracked exclusion")
end)

t:test("snapshot preserves copies under the configured diff policy", function()
  local root = new_repo()
  git(root, { "config", "diff.renames", "copies" })
  local lines = { "a", "b", "c", "d", "e", "f", "g", "h", "i", "j" }
  vim.fn.writefile(lines, root .. "/source")
  git(root, { "add", "source" })
  commit(root)
  vim.fn.writefile(lines, root .. "/copy")
  vim.fn.writefile({ "extra" }, root .. "/source", "a")
  git(root, { "add", "." })

  local result = assert_snapshot_parity(3)
  t.assert_true(result.status_map[root .. "/copy"].staged.C, "copy status")
  t.assert_eq("source", result.status_map[root .. "/copy"].staged_prev_relative, "copy source")
  git(root, { "config", "status.renames", "false" })
  result = assert_snapshot_parity(3)
  t.assert_true(result.status_map[root .. "/copy"].staged.C, "diff copies survive a disabled status rename detector")
end)

t:test("snapshot preserves disabled diff rename detection", function()
  local root = new_repo()
  git(root, { "config", "diff.renames", "false" })
  vim.fn.writefile({ "base" }, root .. "/source")
  git(root, { "add", "source" })
  commit(root)
  git(root, { "mv", "source", "destination" })

  local result = assert_snapshot_parity(3)
  t.assert_true(result.status_map[root .. "/source"].staged.D, "source remains a deletion")
  t.assert_true(result.status_map[root .. "/destination"].staged.A, "destination remains an addition")
end)

t:test("snapshot supports unborn HEAD, intent-to-add, and nested untracked repositories", function()
  local root = new_repo()
  vim.fn.writefile({ "staged" }, root .. "/first")
  git(root, { "add", "first" })
  vim.fn.writefile({ "pending" }, root .. "/intent")
  git(root, { "add", "-N", "intent" })
  vim.fn.mkdir(root .. "/nested", "p")
  git(root .. "/nested", { "init", "-q" })
  vim.fn.writefile({ "nested" }, root .. "/nested/file")

  local result = assert_snapshot_parity(1)
  t.assert_nil(result.status_map[root .. "/first"].staged_old_object_name, "missing HEAD object")
  t.assert_true(result.status_map[root .. "/intent"].unstaged.A, "intent-to-add is an unstaged addition")
end)

t:test("conflict snapshots retain raw index-stage semantics", function()
  local root = new_repo()
  vim.fn.writefile({ "base" }, root .. "/conflict")
  git(root, { "add", "conflict" })
  commit(root)
  local base = vim.trim(git(root, { "hash-object", "-w", "--stdin" }, "base\n"))
  local ours = vim.trim(git(root, { "hash-object", "-w", "--stdin" }, "ours\n"))
  local theirs = vim.trim(git(root, { "hash-object", "-w", "--stdin" }, "theirs\n"))
  git(
    root,
    { "update-index", "--index-info" },
    table.concat({
      "0 " .. string.rep("0", #base) .. "\tconflict",
      "100644 " .. base .. " 1\tconflict",
      "100644 " .. ours .. " 2\tconflict",
      "100644 " .. theirs .. " 3\tconflict",
      "",
    }, "\n")
  )
  vim.fn.writefile({ "resolved but not staged" }, root .. "/conflict")

  local result = assert_snapshot_parity(3)
  t.assert_true(result.status_map[root .. "/conflict"].codes.U, "conflict status")
end)

t:test("gitlink snapshots retain raw diff identities and dirtiness rules", function()
  local root = new_repo()
  local child = root .. "/child" ---@type string
  vim.fn.mkdir(child, "p")
  git(child, { "init", "-q" })
  vim.fn.writefile({ "base" }, child .. "/file")
  git(child, { "add", "file" })
  commit(child)
  git(root, { "add", "child" })
  commit(root)
  vim.fn.writefile({ "second" }, child .. "/file", "a")
  git(child, { "add", "file" })
  commit(child)

  local result = assert_snapshot_parity(3)
  t.assert_eq(
    vim.trim(git(root, { "rev-parse", ":child" })),
    result.status_map[root .. "/child"].unstaged_old_object_name,
    "index gitlink identity"
  )
  git(root, { "add", "child" })
  commit(root)
  vim.fn.writefile({ "untracked inside submodule" }, child .. "/new")
  assert_snapshot_parity(3)
end)

t:test("background status leaves the real index untouched", function()
  local root = new_repo()
  vim.fn.writefile({ "base" }, root .. "/file")
  git(root, { "add", "file" })
  commit(root)
  assert(vim.uv.fs_utime(root .. "/file", 0, 0))
  local before = git(root, { "hash-object", ".git/index" })

  collect()

  t.assert_eq(before, git(root, { "hash-object", ".git/index" }), "index bytes preserved")
end)

t:test("exported tables cannot mutate the native snapshot", function()
  local root = new_repo()
  vim.fn.writefile({ "new" }, root .. "/file")
  local snapshot = collect()
  local exported = snapshot:entries()
  exported[root .. "/file"].display = "wrong"
  exported[root .. "/file"].codes["?"] = nil
  t.assert_eq("U", snapshot:lookup(root .. "/file").display, "native status unchanged")
  t.assert_true(snapshot:equals(collect()), "query identity unaffected by exported mutations")
end)

t:test("recreated untracked directory symlinks preserve descendant rendering", function()
  local root = new_repo()
  vim.fn.mkdir(root .. "/target", "p")
  vim.fn.writefile({ "target" }, root .. "/target/file")
  assert(vim.uv.fs_symlink("target", root .. "/link", { dir = true }))
  git(root, { "add", "." })
  commit(root)
  git(root, { "rm", "link" })
  assert(vim.uv.fs_symlink("target", root .. "/link", { dir = true }))
  assert_snapshot_parity(1)
end)

t:test("cancelled status queries settle without starting fallback queries", function()
  new_repo()
  local token = stl.c.CancellationToken.new()
  local future = status.collect(nil, token)
  token:cancel()

  t.wait_until(function()
    return future:is_done()
  end, 3000, "native cancellation not acknowledged")
  t.assert_true(future:is_done(), "cancelled outer Future settled")
  t.assert_true(future:is_failed(), "cancelled snapshot was not published")
end)

t:run()
