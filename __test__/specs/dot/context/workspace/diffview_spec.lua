require("ark.bootstrap").setup()
local t = require("__test__.support.harness").new()

t:test("diffview context persists the untracked visibility default", function()
  -- A fresh instance, so the case leaves the runtime's context alone.
  local context = assert(loadfile("lua/dot/context/workspace/diffview.lua"))()

  t.assert_true(context.defaults().flag_untracked, "default visibility")
  t.assert_false(context.normalize({ flag_untracked = false }).flag_untracked, "normalized visibility")
  t.assert_true(context.normalize({ flag_untracked = "invalid" }).flag_untracked, "invalid visibility fallback")

  context.flag_untracked:next(false)
  t.assert_false(context.dump().flag_untracked, "dumped visibility")
  context.load({ flag_untracked = true })
  t.assert_true(context.flag_untracked:snapshot(), "loaded visibility")
end)

t:run()
