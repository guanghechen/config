---@diagnostic disable: undefined-global
--- Run with: nvim -l lua/__test__/stl/git/exec.lua

local harness = require("__test__.harness")

local t = harness.new("stl.git.exec")

t:patch_table(vim, "schedule", function(callback)
  callback()
end)

local exec = require("stl.git.exec")

t:test("exec_async forwards Git stderr on failure", function()
  local command = {} ---@type string[]
  t:patch_table(vim, "system", function(cmd, opts, callback)
    command = cmd
    t.assert_true(opts.text, "text output")
    callback({ code = 128, stdout = "", stderr = "fatal: index is locked\n" })
    return {}
  end)

  local result = nil ---@type table|nil
  exec.exec_async({ "add", "--", "file.txt" }, { cwd = "/repo" }, function(lines, code, stderr)
    result = { lines = lines, code = code, stderr = stderr }
  end)

  t.assert_eq("git -C /repo add -- file.txt", table.concat(command, " "), "command")
  local actual = assert(result, "callback result")
  t.assert_eq(0, #actual.lines, "stdout lines")
  t.assert_eq(128, actual.code, "exit code")
  t.assert_eq("fatal: index is locked\n", actual.stderr, "stderr")
end)

t:run()
