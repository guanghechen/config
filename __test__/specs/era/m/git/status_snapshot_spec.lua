local bootstrap = require("__test__.support.bootstrap")
local fs = require("__test__.support.fs")
local git_buffer = require("__test__.support.git_buffer")
local harness = require("__test__.support.harness")
local git_exec = require("stl.git.exec")

local t = harness.new()
local git = require("__test__.support.git")
local workspace = "" ---@type string

git_buffer.with_futures(t)
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

---@param object_format                 ?string
---@return string
local function new_repo(object_format)
  local root = git.repo(t, object_format and { "--object-format=" .. object_format } or nil)
  workspace = root
  return root
end

---@param opts                          ?era.m.git.status.ICollectOpts
---@return yoz.git.StatusSnapshot
local function collect(opts)
  return assert(t.await(status.collect(opts)))
end

---@param processes                     integer
---@param include_untracked             ?boolean
---@return era.m.git.status.ICollectResult
local function assert_snapshot_parity(processes, include_untracked)
  local snapshot = collect({ include_untracked = include_untracked })
  t.assert_eq(processes, snapshot:stats(), "default snapshot process count")
  local current = snapshot:export()
  local raw = t.await(reference.collect({ include_numstat = true, include_untracked = include_untracked }))
  t.assert_same(raw.status_map, current.status_map, "raw and porcelain status maps differ")
  t.assert_same(raw.status_groups, current.status_groups, "raw and porcelain status groups differ")
  local numbered = collect({ include_numstat = true, include_untracked = include_untracked }):export()
  t.assert_same(raw, numbered, "native and Lua numstat snapshots differ")
  local aggregated = reference.aggregate(raw.status_map)
  t:patch_global("era", {
    m = {
      git = {
        -- The Lua reference resolves through the state's aggregated tables.
        state = {
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
        local actual, actual_name_hl = status.calc_info(snapshot, query, kind, 3, actual_hl)
        t.assert_eq(expected, actual, "status text parity")
        t.assert_eq(expected_name_hl, actual_name_hl, "status name highlight parity")
        t.assert_same(expected_hl, actual_hl, "status segment highlight parity")
      end
    end
  end
  return current
end

t:test("ordinary snapshots use one query and preserve mixed changes and deletions", function()
  local root = new_repo()
  for _, name in ipairs({ "mixed", "modified", "deleted", "staged-delete" }) do
    fs.write(root .. "/" .. name, { name })
  end
  git.commit(root, "fixture")
  vim.fn.writefile({ "staged" }, root .. "/mixed", "a")
  git.run(root, { "add", "mixed" })
  vim.fn.writefile({ "unstaged" }, root .. "/mixed", "a")
  vim.fn.writefile({ "modified" }, root .. "/modified", "a")
  assert(vim.uv.fs_unlink(root .. "/deleted"))
  git.run(root, { "rm", "staged-delete" })
  fs.write(root .. "/untracked", { "new" })

  local result = assert_snapshot_parity(1)
  t.assert_eq("mixed", result.status_map[root .. "/mixed"].stage, "mixed change")
  t.assert_true(result.status_map[root .. "/deleted"].unstaged.D, "worktree deletion")
  t.assert_true(result.status_map[root .. "/staged-delete"].staged.D, "staged deletion")
end)

t:test("snapshot preserves full SHA-256 object identities", function()
  local root = new_repo("sha256")
  fs.write(root .. "/file", { "base" })
  git.commit(root, "fixture")
  local old_object = git.run(root, { "rev-parse", "HEAD:file" }):gsub("\n$", "")
  vim.fn.writefile({ "staged" }, root .. "/file", "a")
  git.run(root, { "add", "file" })
  local new_object = git.run(root, { "rev-parse", ":file" }):gsub("\n$", "")
  vim.fn.writefile({ "unstaged" }, root .. "/file", "a")

  local entry = assert_snapshot_parity(1).status_map[root .. "/file"]
  t.assert_eq(64, #old_object, "SHA-256 repository")
  t.assert_eq(old_object, entry.staged_old_object_name, "full HEAD identity")
  t.assert_eq(new_object, entry.staged_new_object_name, "full staged identity")
  t.assert_eq(new_object, entry.unstaged_old_object_name, "full unstaged base identity")
end)

t:test("snapshot and Lua exports preserve native pathname bytes", function()
  local root = new_repo()
  -- macOS and Windows require Unicode filenames; other Unix systems also exercise invalid UTF-8.
  local suffix = (package.config:sub(1, 1) == "/" and vim.uv.os_uname().sysname ~= "Darwin") and "\255" or "字"
  local directory = root .. "/raw-" .. suffix
  assert(vim.uv.fs_mkdir(directory, 493))
  local path = directory .. "/file-" .. suffix
  fs.write(path, { "base" })
  git.commit(root, "fixture")
  vim.fn.writefile({ "changed" }, path, "a")

  local result = assert_snapshot_parity(1)
  t.assert_eq(path, result.status_map[path].path, "exported pathname bytes")
  t.assert_eq("M", collect():lookup(directory, true).display, "native directory lookup")
end)

t:test("snapshot preserves mixed changes, renames, deletes, and literal pathnames", function()
  local root = new_repo()
  for _, name in ipairs({ "source", "mixed", "deleted", "recreated" }) do
    fs.write(root .. "/" .. name, { name })
  end
  git.commit(root, "fixture")
  git.run(root, { "mv", "source", "renamed\tfile" })
  vim.fn.writefile({ "staged" }, root .. "/mixed", "a")
  git.run(root, { "add", "mixed" })
  vim.fn.writefile({ "unstaged" }, root .. "/mixed", "a")
  vim.fn.writefile({ "renamed and edited" }, root .. "/renamed\tfile", "a")
  assert(vim.uv.fs_unlink(root .. "/deleted"))
  git.run(root, { "rm", "recreated" })
  fs.write(root .. "/recreated", { "new content" })
  fs.write(root .. "/space name", { "fresh" })
  fs.write(root .. "/line\nbreak", { "fresh" })

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
  git.run(root, { "config", "diff.renames", "copies" })
  local lines = { "a", "b", "c", "d", "e", "f", "g", "h", "i", "j" }
  fs.write(root .. "/source", lines)
  git.commit(root, "fixture")
  fs.write(root .. "/copy", lines)
  vim.fn.writefile({ "extra" }, root .. "/source", "a")
  git.run(root, { "add", "." })

  local result = assert_snapshot_parity(3)
  t.assert_true(result.status_map[root .. "/copy"].staged.C, "copy status")
  t.assert_eq("source", result.status_map[root .. "/copy"].staged_prev_relative, "copy source")
  git.run(root, { "config", "status.renames", "false" })
  result = assert_snapshot_parity(3)
  t.assert_true(result.status_map[root .. "/copy"].staged.C, "diff copies survive a disabled status rename detector")
end)

t:test("snapshot preserves disabled diff rename detection", function()
  local root = new_repo()
  git.run(root, { "config", "diff.renames", "false" })
  fs.write(root .. "/source", { "base" })
  git.commit(root, "fixture")
  git.run(root, { "mv", "source", "destination" })

  local result = assert_snapshot_parity(3)
  t.assert_true(result.status_map[root .. "/source"].staged.D, "source remains a deletion")
  t.assert_true(result.status_map[root .. "/destination"].staged.A, "destination remains an addition")
end)

t:test("snapshot supports unborn HEAD, intent-to-add, and nested untracked repositories", function()
  local root = new_repo()
  fs.write(root .. "/first", { "staged" })
  git.run(root, { "add", "first" })
  fs.write(root .. "/intent", { "pending" })
  git.run(root, { "add", "-N", "intent" })
  vim.fn.mkdir(root .. "/nested", "p")
  git.init(root .. "/nested")
  fs.write(root .. "/nested/file", { "nested" })

  local result = assert_snapshot_parity(1)
  t.assert_nil(result.status_map[root .. "/first"].staged_old_object_name, "missing HEAD object")
  t.assert_true(result.status_map[root .. "/intent"].unstaged.A, "intent-to-add is an unstaged addition")
end)

t:test("conflict snapshots retain raw index-stage semantics", function()
  local root = new_repo()
  fs.write(root .. "/conflict", { "base" })
  git.commit(root, "fixture")
  local base = vim.trim(git.run(root, { "hash-object", "-w", "--stdin" }, "base\n"))
  local ours = vim.trim(git.run(root, { "hash-object", "-w", "--stdin" }, "ours\n"))
  local theirs = vim.trim(git.run(root, { "hash-object", "-w", "--stdin" }, "theirs\n"))
  git.run(
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
  fs.write(root .. "/conflict", { "resolved but not staged" })

  local result = assert_snapshot_parity(3)
  t.assert_true(result.status_map[root .. "/conflict"].codes.U, "conflict status")
end)

t:test("gitlink snapshots retain raw diff identities and dirtiness rules", function()
  local root = new_repo()
  local child = root .. "/child" ---@type string
  vim.fn.mkdir(child, "p")
  git.init(child)
  fs.write(child .. "/file", { "base" })
  git.commit(child, "fixture")
  git.commit(root, "fixture")
  vim.fn.writefile({ "second" }, child .. "/file", "a")
  git.commit(child, "fixture")

  local result = assert_snapshot_parity(3)
  t.assert_eq(
    vim.trim(git.run(root, { "rev-parse", ":child" })),
    result.status_map[root .. "/child"].unstaged_old_object_name,
    "index gitlink identity"
  )
  git.commit(root, "fixture")
  fs.write(child .. "/new", { "untracked inside submodule" })
  assert_snapshot_parity(3)
end)

t:test("background status leaves the real index untouched", function()
  local root = new_repo()
  fs.write(root .. "/file", { "base" })
  git.commit(root, "fixture")
  assert(vim.uv.fs_utime(root .. "/file", 0, 0))
  local before = git.run(root, { "hash-object", ".git/index" })

  collect()

  t.assert_eq(before, git.run(root, { "hash-object", ".git/index" }), "index bytes preserved")
end)

t:test("exported tables cannot mutate the native snapshot", function()
  local root = new_repo()
  fs.write(root .. "/file", { "new" })
  local snapshot = collect()
  local exported = snapshot:entries()
  exported[root .. "/file"].display = "wrong"
  exported[root .. "/file"].codes["?"] = nil
  t.assert_eq("U", snapshot:lookup(root .. "/file").display, "native status unchanged")
  t.assert_true(snapshot:equals(collect()), "query identity unaffected by exported mutations")
end)

t:test("recreated untracked directory symlinks preserve descendant rendering", function()
  local root = new_repo()
  fs.write(root .. "/target/file", { "target" })
  assert(vim.uv.fs_symlink("target", root .. "/link", { dir = true }))
  git.commit(root, "fixture")
  git.run(root, { "rm", "link" })
  assert(vim.uv.fs_symlink("target", root .. "/link", { dir = true }))
  assert_snapshot_parity(1)
end)

t:test("cancelled status queries settle without starting fallback queries", function()
  new_repo()
  local token = stl.c.CancellationToken.new()
  local future = status.collect(nil, token)
  token:cancel()

  t.settle(future)
  t.assert_true(future:is_done(), "cancelled outer Future settled")
  t.assert_true(future:is_failed(), "cancelled snapshot was not published")
end)

t:run()
