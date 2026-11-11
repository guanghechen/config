local bootstrap = require("__test__.support.bootstrap")
local harness = require("__test__.support.harness")

local t = harness.new()
local maximized = assert(loadfile("lua/dot/state/maximized.lua"))()

bootstrap.with_runtime(t, {
  stl = {
    box = require("stl.box"),
    nvim = {
      fn = {
        is_statusline_visible = function()
          return false
        end,
      },
    },
  },
})

t:test("a maximized float covers the tabline and leaves the status line and the command line in sight", function()
  t:patch_table(stl.nvim.fn, "is_statusline_visible", function()
    return true
  end)
  local cfg = maximized.compute_float_maximized_wincfg({
    relative = "editor",
    row = 2,
    col = 3,
    width = 20,
    height = 5,
    border = "single",
    zindex = 50,
  })

  t.assert_eq(0, cfg.row, "top row, over the tabline")
  -- The rounded frame takes a row above and below.
  t.assert_eq(vim.o.lines - vim.o.cmdheight - 1, cfg.row + cfg.height + 2, "status line row stays free")
  t.assert_eq(51, cfg.zindex, "above the float it maximizes")
end)

t:run()
