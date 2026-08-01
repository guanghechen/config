---@diagnostic disable: undefined-global
--- Run with: nvim -l lua/__test__/era/command.lua

local harness = require("__test__.harness")

local t = harness.new("era.command")

t:test("command definitions and implementations stay symmetric", function()
  local next_info_calls = 0
  local prev_info_calls = 0
  local enums = require("stl.e")

  t:patch_global("stl", {
    e = enums,
    reporter = {
      error = function() end,
      warn = function() end,
    },
  })
  t:patch_global("dot", {
    state = { status = { set_winnr_command = function() end } },
    var = { themes = {}, toggler = {} },
  })
  t:patch_global("era", {
    m = {
      lsp = {
        diagnostic = {
          goto_next_info = function()
            next_info_calls = next_info_calls + 1
          end,
          goto_prev_info = function()
            prev_info_calls = prev_info_calls + 1
          end,
        },
      },
    },
  })
  t:patch_table(vim.api, "nvim_create_user_command", function() end)

  local Command = assert(loadfile("lua/dot/command.lua"))()
  dot.command = Command
  assert(loadfile("lua/era/command.lua"))()

  Command.definitions.diagnostic.goto_next_info:execute()
  Command.definitions.diagnostic.goto_prev_info:execute()

  t.assert_eq(1, next_info_calls, "next info implementation")
  t.assert_eq(1, prev_info_calls, "previous info implementation")
end)

t:run()
