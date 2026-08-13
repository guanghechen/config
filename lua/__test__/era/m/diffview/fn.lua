---@diagnostic disable: undefined-global
--- Test for era.m.diffview.fn module
--- Run with: nvim -l lua/__test__/era/m/diffview/fn.lua

local bootstrap = require("__test__.bootstrap")
local harness = require("__test__.harness")

local t = harness.new("era.m.diffview.fn")

local relative_args = nil ---@type { from: string, to: string }|nil
local log_opts = nil ---@type { layout: integer|nil, path: string|nil }|nil

bootstrap.with_runtime(t, {
  dot = {
    path = {
      workspace = function()
        return [[C:\repo]]
      end,
    },
  },
  era = {
    m = {
      diffview = {
        cmd = {
          log = function(opts)
            log_opts = opts
          end,
        },
      },
    },
  },
  stl = {
    os = {
      path = {
        relative = function(from, to)
          relative_args = { from = from, to = to }
          return "lua/era/m/im/wsl.lua"
        end,
      },
    },
    reporter = { warn = function() end },
  },
})

local Fn = require("era.m.diffview.fn")

t:test("open_file_history uses Git separators for Windows paths", function()
  local filepath = [[C:\repo\lua\era\m\im\wsl.lua]]

  Fn.open_file_history({ filepath = filepath, layout = 3 })

  t.assert_eq([[C:\repo]], relative_args.from, "relative path root")
  t.assert_eq(filepath, relative_args.to, "relative path target")
  t.assert_eq("lua/era/m/im/wsl.lua", log_opts.path, "Git path filter")
  t.assert_eq(3, log_opts.layout, "layout")
end)

t:run()
