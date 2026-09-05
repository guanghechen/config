--- Run with: nvim -l __test__/run.lua __test__/specs/era/m/term/action_spec.lua
---@diagnostic disable: undefined-global
--- Test for era.m.term.action module

local bootstrap = require("__test__.support.bootstrap")
local harness = require("__test__.support.harness")

local t = harness.new("era.m.term.action")

local created = nil ---@type era.m.term.ICreateParams|nil
local focused = false ---@type boolean
local toggled = nil ---@type era.m.term.IToggleAndFocusParams|nil

bootstrap.with_runtime(t, {
  dot = {
    path = {
      cwd = function()
        return "/repo"
      end,
      dirname = function(filepath)
        return filepath .. "/parent"
      end,
      locate_cache_filepath = function()
        return "/cache/yazi chooser.txt"
      end,
    },
  },
  era = {
    m = {
      term = {
        state = {
          create = function(params)
            created = params
            return params
          end,
        },
        widget = {
          focus = function()
            focused = true
          end,
          toggle_and_focus = function(_, params)
            toggled = params
          end,
        },
      },
    },
  },
  yoz = {
    fn = {
      uuid = function()
        return "terminal-uuid"
      end,
    },
  },
})

local action = require("era.m.term.action")

local function reset()
  created = nil
  focused = false
  toggled = nil
end

t:test("create: launches the shell directly", function()
  reset()

  action.create()

  t.assert_true(focused, "widget should focus")
  t.assert_true(created ~= nil, "terminal should be created")
  ---@diagnostic disable-next-line: need-check-nil
  t.assert_eq("table", type(created.cmd), "command type")
  ---@diagnostic disable-next-line: need-check-nil
  t.assert_eq(vim.o.shell, created.cmd[1], "shell executable")
  ---@diagnostic disable-next-line: need-check-nil
  t.assert_eq(1, #created.cmd, "argument count")
end)

t:test("lazygit_cwd: launches lazygit directly", function()
  reset()

  action.lazygit_cwd()

  t.assert_true(toggled ~= nil, "terminal should toggle")
  ---@diagnostic disable-next-line: need-check-nil
  t.assert_eq("/repo", toggled.cwd, "cwd")
  ---@diagnostic disable-next-line: need-check-nil
  t.assert_eq("table", type(toggled.cmd), "command type")
  ---@diagnostic disable-next-line: need-check-nil
  t.assert_eq("lazygit", toggled.cmd[1], "executable")
  ---@diagnostic disable-next-line: need-check-nil
  t.assert_eq(1, #toggled.cmd, "argument count")
end)

t:test("lazygit_file_history: preserves the filepath as one argument", function()
  reset()
  t:patch_table(vim.api, "nvim_get_current_buf", function()
    return 7
  end)
  t:patch_table(vim.api, "nvim_buf_get_name", function()
    return "/repo/file with spaces.lua"
  end)

  action.lazygit_file_history()

  t.assert_true(toggled ~= nil, "terminal should toggle")
  ---@diagnostic disable-next-line: need-check-nil
  t.assert_eq("lazygit", toggled.cmd[1], "executable")
  ---@diagnostic disable-next-line: need-check-nil
  t.assert_eq("-f", toggled.cmd[2], "file-history flag")
  ---@diagnostic disable-next-line: need-check-nil
  t.assert_eq("/repo/file with spaces.lua", toggled.cmd[3], "filepath")
  ---@diagnostic disable-next-line: need-check-nil
  t.assert_eq(3, #toggled.cmd, "argument count")
end)

t:test("yazi_cwd: preserves paths as argv entries", function()
  reset()

  action.yazi_cwd()

  t.assert_true(toggled ~= nil, "terminal should toggle")
  ---@diagnostic disable-next-line: need-check-nil
  t.assert_eq("yazi", toggled.cmd[1], "executable")
  ---@diagnostic disable-next-line: need-check-nil
  t.assert_eq("/repo/parent", toggled.cmd[2], "directory argument")
  ---@diagnostic disable-next-line: need-check-nil
  t.assert_eq("--chooser-file=/cache/yazi chooser.txt", toggled.cmd[3], "chooser argument")
  ---@diagnostic disable-next-line: need-check-nil
  t.assert_eq(3, #toggled.cmd, "argument count")
end)

t:run()
