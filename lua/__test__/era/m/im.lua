---@diagnostic disable: undefined-global
--- Test for era.m.im process commands
--- Run with: nvim -l lua/__test__/era/m/im.lua

local bootstrap = require("__test__.bootstrap")
local harness = require("__test__.harness")

local t = harness.new("era.m.im")
local reports = {} ---@type table[]

bootstrap.with_runtime(t, {
  dot = {
    path = {
      locate_app_config_home = function()
        return "/app"
      end,
      join = function(...)
        return table.concat({ ... }, "/")
      end,
    },
  },
  stl = {
    env = { IS_X64 = true, IS_X86 = false },
    reporter = {
      error = function(report)
        reports[#reports + 1] = report
      end,
    },
  },
})

---@param module_name                   string
---@param english_output                string
---@param chinese_arg                   string
local function test_process_commands(module_name, english_output, chinese_arg)
  local commands = {} ---@type string[][]
  t:patch_table(vim.fn, "executable", function()
    return 1
  end)
  t:patch_table(vim.fn, "system", function(cmd)
    commands[#commands + 1] = cmd
    return #commands == 1 and english_output .. "\n" or ""
  end)

  local im = require(module_name)
  t.assert_eq("English", im.get_input_method(), "detected input method")
  im.set_input_method("Chinese")

  t.assert_eq("table", type(commands[1]), "get command type")
  t.assert_eq(1, #commands[1], "get argument count")
  t.assert_eq("table", type(commands[2]), "set command type")
  t.assert_eq(chinese_arg, commands[2][2], "set argument")
end

t:test("osx: executes im-select with argv", function()
  test_process_commands("era.m.im.osx", "com.apple.keylayout.ABC", "com.apple.inputmethod.SCIM.ITABC")
end)

t:test("win: executes im-select with argv", function()
  test_process_commands("era.m.im.win", "1033", "2052")
end)

t:test("wsl: executes im-select with argv", function()
  test_process_commands("era.m.im.wsl", "1033", "2052")
end)

t:test("unavailable executable is rejected before process launch", function()
  reports = {}
  local launched = false
  t:patch_table(vim.fn, "executable", function()
    return 0
  end)
  t:patch_table(vim.fn, "system", function()
    launched = true
    return ""
  end)

  local im = require("era.m.im.osx")
  t.assert_nil(im.get_input_method(), "input method")
  t.assert_false(launched, "process launch")
  t.assert_eq(1, #reports, "error count")
end)

t:test("spawn failure is reported without escaping the module boundary", function()
  reports = {}
  t:patch_table(vim.fn, "executable", function()
    return 1
  end)
  t:patch_table(vim.fn, "system", function()
    error("spawn failed")
  end)

  local im = require("era.m.im.osx")
  t.assert_nil(im.get_input_method(), "input method")
  im.set_input_method("English")

  t.assert_eq(2, #reports, "error count")
  t.assert_eq("get_input_method", reports[1].subject, "get report subject")
  t.assert_eq("set_input_method", reports[2].subject, "set report subject")
end)

t:run()
