local bootstrap = require("__test__.support.bootstrap")
local Future = require("stl.c.future")
local fs = require("__test__.support.fs")
local git = require("__test__.support.git")
local harness = require("__test__.support.harness")

local t = harness.new()

bootstrap.with_runtime(t, {
  stl = {
    c = { Future = Future },
    reporter = {
      error = function() end,
      warn = function() end,
    },
  },
  yoz = {
    canonical_path = {
      to_os_path = function(filepath)
        return filepath:gsub("/", "\\")
      end,
    },
  },
})
t:patch_table(vim, "schedule", function(callback)
  callback()
end)

local act = require("stl.git.act")

t:test("actions convert filesystem arguments and pass paths as literal pathspecs", function()
  local commands = {} ---@type string[][]
  t:patch_table(vim, "system", function(command, _, callback)
    commands[#commands + 1] = command
    callback({ code = 0, stdout = "abc123\n", stderr = "" })
    return { kill = function() end }
  end)

  act.add_intent_to_add("C:/repo", "lua/era/m/git/status.lua")
  act.apply_patch("C:/repo", "patch")
  act.clone("https://example.test/repo.git", "C:/repos/example", nil)
  act.hash_object("C:/repo", "lua/era/m/git/status.lua", "content")
  act.reset_file("C:/repo", "lua/era/m/git/status.lua")
  act.stage_file("C:/repo", "lua/era/m/git/status.lua")
  act.unstage_file("C:/repo", "lua/era/m/git/status.lua")
  act.update_index("C:/repo", "100644", "abc123", "lua/era/m/git/status.lua")
  act.stage_file("//server/share/repo", "lua/era/m/git/status.lua")

  t.assert_eq(9, #commands, "Git commands")
  for index, command in ipairs(commands) do
    if index == 3 then
      t.assert_eq([[C:\repos\example]], command[#command], "clone destination")
    elseif index == 9 then
      t.assert_eq([[\\server\share\repo]], command[3], "UNC Git cwd")
    else
      t.assert_eq([[C:\repo]], command[3], "Git cwd " .. index)
    end
  end
  t.assert_eq("lua/era/m/git/status.lua", commands[1][#commands[1]], "add pathspec")
  t.assert_eq("lua/era/m/git/status.lua", commands[4][8], "hash-object path")
  t.assert_eq("lua/era/m/git/status.lua", commands[5][#commands[5]], "checkout pathspec")
  t.assert_eq("100644,abc123,lua/era/m/git/status.lua", commands[8][#commands[8]], "cacheinfo path")
  -- Without it `a[1].txt` also matches `a1.txt`, so checkout would discard that file's changes too.
  for _, index in ipairs({ 1, 5, 6, 7, 9 }) do
    t.assert_eq("--literal-pathspecs", commands[index][4], "literal pathspecs " .. index)
  end
end)

t:test("a bracketed path restores and stages only itself, not the files its pattern matches", function()
  t:patch_table(yoz.canonical_path, "to_os_path", function(filepath)
    return filepath
  end)
  local root = git.repo(t)
  fs.write(root .. "/a[1].txt", { "x" })
  fs.write(root .. "/a1.txt", { "y" })
  git.commit(root, "base")
  fs.write(root .. "/a[1].txt", { "x2" })
  fs.write(root .. "/a1.txt", { "y2" })

  t.assert_true(t.await(act.reset_file(root, "a[1].txt")), "restored")
  t.assert_same({ "x" }, vim.fn.readfile(root .. "/a[1].txt"), "the path itself is restored")
  t.assert_same({ "y2" }, vim.fn.readfile(root .. "/a1.txt"), "the file its pattern matches keeps its change")

  fs.write(root .. "/a[1].txt", { "x3" })
  t.assert_true(t.await(act.stage_file(root, "a[1].txt")), "staged")
  t.assert_eq("a[1].txt\n", git.run(root, { "diff", "--cached", "--name-only" }), "only the path itself is staged")
end)

t:test("hash and index writes killed by a signal fail and are reported", function()
  local reports = bootstrap.with_reporter(t)
  -- A process killed by a signal exits with code 0 and no output.
  t:patch_table(vim, "system", function(_, _, callback)
    callback({ code = 0, signal = 9, stdout = "", stderr = "" })
    return { kill = function() end }
  end)

  t.assert_nil(t.await(act.hash_object("/repo", "f.txt", "content")), "no object name")
  t.assert_false(t.await(act.update_index("/repo", "100644", "abc123", "f.txt")), "index not updated")
  t.assert_same({ "Failed to hash object", "Failed to update index" }, bootstrap.messages(reports.warn))
end)

t:run()
