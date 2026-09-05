--- Run with: nvim -l __test__/run.lua __test__/specs/era/plugin/mini-ai_spec.lua
---@diagnostic disable: undefined-global

local harness = require("__test__.support.harness")

local t = harness.new("era.plugin.mini-ai")
local expected = { from = { line = 2, col = 1 }, to = { line = 3, col = 1 }, vis_mode = "V" }

t:patch_global("era", {
  m = {
    git = {
      hunk = {
        ai_textobject = function()
          return { expected }
        end,
      },
    },
  },
})
t:patch_table(package.loaded, "mini.ai", {
  gen_spec = {
    treesitter = function()
      return {}
    end,
    function_call = function()
      return {}
    end,
  },
})

local plugin = assert(loadfile("lua/era/plugin/mini-ai.lua"))()

t:test("opts routes the h textobject to unstaged Git hunks", function()
  local opts = plugin.opts()
  local regions = opts.custom_textobjects.h("i", "h", {})

  t.assert_eq(expected, regions[1], "hunk region")
end)

t:run()
