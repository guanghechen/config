--- Run with: nvim -l __test__/run.lua __test__/specs/era/m/diffview/commit_format_spec.lua
---@diagnostic disable: undefined-global

local harness = require("__test__.support.harness")

local t = harness.new("era.m.diffview.commit_format")
local format = assert(loadfile("lua/era/m/diffview/commit_format.lua"))()

t:test("shortens authors to lazygit's two-column form", function()
  t.assert_eq("JD", format.short_author("Jesse Duffield"), "two-word initials")
  t.assert_eq("al", format.short_author("alice"), "single-word prefix")
  t.assert_eq("张", format.short_author("张三"), "wide first grapheme")
  t.assert_eq("", format.short_author(""), "empty author")
end)

t:test("renders known gitmoji and preserves unknown shortcodes", function()
  t.assert_eq("✨ feat: graph 🐛", format.render_gitmoji(":sparkles: feat: graph :bug:"), "known gitmoji")
  t.assert_eq(":custom: message", format.render_gitmoji(":custom: message"), "unknown shortcode")
end)

t:run()
