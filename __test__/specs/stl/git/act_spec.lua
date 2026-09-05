--- Run with: nvim -l __test__/run.lua __test__/specs/stl/git/act_spec.lua
---@diagnostic disable: undefined-global

local bootstrap = require("__test__.support.bootstrap")
local Future = require("stl.c.future")
local harness = require("__test__.support.harness")

local t = harness.new("stl.git.act")

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

t:test("actions convert filesystem arguments without changing Git pathspecs", function()
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
  t.assert_eq("lua/era/m/git/status.lua", commands[4][7], "hash-object path")
  t.assert_eq("lua/era/m/git/status.lua", commands[5][#commands[5]], "checkout pathspec")
  t.assert_eq("100644,abc123,lua/era/m/git/status.lua", commands[8][#commands[8]], "cacheinfo path")
end)

t:run()
