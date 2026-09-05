--- Run with: nvim -l __test__/run.lua __test__/specs/stl/tmux_spec.lua
---@diagnostic disable: undefined-global
--- Test for stl.tmux module

local harness = require("__test__.support.harness")

local t = harness.new("stl.tmux")

t:patch_table(vim.env, "TMUX", "/tmp/nvim-test-tmux,1,0")
local schedule_count = 0 ---@type integer
t:patch_table(vim, "schedule", function(callback)
  schedule_count = schedule_count + 1
  callback()
end)
local tmux = require("stl.tmux")

---@param result                       { code: integer, stdout?: string }
---@return string[], boolean|nil
local function query(result)
  local command = {} ---@type string[]
  local callback_count = 0 ---@type integer
  local schedule_count_before = schedule_count ---@type integer
  t:patch_table(vim, "system", function(cmd, opts, callback)
    command = cmd
    t.assert_true(opts.text, "text output")
    t.assert_eq(1000, opts.timeout, "query timeout")
    callback(result)
    return {}
  end)

  local actual ---@type boolean|nil
  tmux.query_tmux_pane_zoomed(function(is_zoomed)
    callback_count = callback_count + 1
    actual = is_zoomed
  end)
  t.assert_eq(schedule_count_before + 1, schedule_count, "scheduled callback")
  t.assert_eq(1, callback_count, "callback count")
  return command, actual
end

t:test("query_tmux_pane_zoomed: reports a single pane as zoomed", function()
  local command, is_zoomed = query({ code = 0, stdout = "1:0\n" })

  t.assert_eq("tmux", command[1], "executable")
  t.assert_eq("-S", command[2], "socket flag")
  t.assert_eq("/tmp/nvim-test-tmux", command[3], "socket")
  t.assert_eq("display-message", command[4], "command")
  t.assert_true(is_zoomed, "single pane")
end)

t:test("query_tmux_pane_zoomed: reports an unzoomed multi-pane window", function()
  local _, is_zoomed = query({ code = 0, stdout = "3:0\n" })

  t.assert_false(is_zoomed, "unzoomed panes")
end)

t:test("query_tmux_pane_zoomed: reports a zoomed multi-pane window", function()
  local _, is_zoomed = query({ code = 0, stdout = "3:1\n" })

  t.assert_true(is_zoomed, "zoomed panes")
end)

t:test("query_tmux_pane_zoomed: degrades on command failure", function()
  local _, is_zoomed = query({ code = 1, stdout = "" })

  t.assert_nil(is_zoomed, "failed command")
end)

t:test("query_tmux_pane_zoomed: degrades on timeout", function()
  local _, is_zoomed = query({ code = 124, stdout = "" })

  t.assert_nil(is_zoomed, "timed out command")
end)

t:test("query_tmux_pane_zoomed: degrades on malformed output", function()
  local _, is_zoomed = query({ code = 0, stdout = "not-a-status\n" })

  t.assert_nil(is_zoomed, "malformed output")
end)

t:test("query_tmux_pane_zoomed: degrades when the process cannot start", function()
  t:patch_table(vim, "system", function()
    error("spawn failed")
  end)

  local actual = false ---@type boolean|nil
  local callback_count = 0 ---@type integer
  local schedule_count_before = schedule_count ---@type integer
  tmux.query_tmux_pane_zoomed(function(is_zoomed)
    callback_count = callback_count + 1
    actual = is_zoomed
  end)

  t.assert_eq(schedule_count_before + 1, schedule_count, "scheduled callback")
  t.assert_eq(1, callback_count, "callback count")
  t.assert_nil(actual, "spawn failure")
end)

t:test("get_tmux_env_value: executes tmux with argv", function()
  local command = {} ---@type string[]
  t:patch_table(vim.fn, "system", function(cmd)
    command = cmd
    return "FOO=value with spaces\n"
  end)

  local value = tmux.get_tmux_env_value("FOO")

  t.assert_eq("value with spaces", value, "environment value")
  t.assert_eq("tmux", command[1], "executable")
  t.assert_eq("-S", command[2], "socket flag")
  t.assert_eq("/tmp/nvim-test-tmux", command[3], "socket")
  t.assert_eq("show-environment", command[4], "command")
  t.assert_eq("FOO", command[5], "environment name")
end)

t:run()
