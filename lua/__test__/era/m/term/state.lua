---@diagnostic disable: undefined-global
--- Test for era.m.term.state module
--- Run with: nvim -l lua/__test__/era/m/term/state.lua

local bootstrap = require("__test__.bootstrap")
local harness = require("__test__.harness")

local t = harness.new("era.m.term.state")

local Observable = {}

function Observable.from_value(initial)
  local value = initial ---@type any
  return {
    next = function(_, next_value)
      value = next_value
    end,
    snapshot = function()
      return value
    end,
  }
end

bootstrap.with_runtime(t, {
  dot = {
    path = {
      cwd = function()
        return "/repo"
      end,
    },
  },
  stl = {
    c = { Observable = Observable },
    fn = { noop = function() end },
  },
})

local state = require("era.m.term.state")

t:test("create: uses a direct shell command by default", function()
  local termmeta = state.create({
    uuid = "default-shell",
    name = "shell",
    type = "shell",
  })

  t.assert_eq("table", type(termmeta.cmd), "command type")
  t.assert_eq(vim.o.shell, termmeta.cmd[1], "shell executable")
  t.assert_eq(1, #termmeta.cmd, "argument count")
end)

t:run()
