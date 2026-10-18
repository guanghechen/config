--- Run with: nvim -l __test__/run.lua __test__/specs/dot/command_spec.lua
---@diagnostic disable: undefined-global

local bootstrap = require("__test__.support.bootstrap")
local harness = require("__test__.support.harness")

local t = harness.new("dot.command")

bootstrap.with_global(t, "stl", { reporter = { warn = function() end } })
bootstrap.with_global(t, "dot", { var = { toggler = {}, themes = {} } })

assert(loadfile("lua/dot/command.lua"))()

t:test("only a command declared with a range accepts the '<,'> of a Visual selection", function()
  local commands = vim.api.nvim_get_commands({})
  t.assert_eq(".", commands.Fjsonviewvisual.range, "the selection preview accepts a range")
  t.assert_nil(commands.Fjsonviewnormal.range, "the line preview keeps refusing a range")
end)

t:run()
