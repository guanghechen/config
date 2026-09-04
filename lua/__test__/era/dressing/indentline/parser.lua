--- Run with: nvim -l lua/__test__/era/dressing/indentline/parser.lua

local harness = require("__test__.harness")

local t = harness.new("era.dressing.indentline.parser")
local parser = require("era.dressing.indentline.parser")

t:test("indent level expands tabs using shiftwidth", function()
  local level, is_all_whitespace, whitespace_length = parser.get_indent_level("\t  value", 2)
  t.assert_eq(2, level, "indent level")
  t.assert_false(is_all_whitespace, "non-blank line")
  t.assert_eq(3, whitespace_length, "source whitespace length")
end)

t:test("non-dedent scopes preserve the deeper adjacent indent on blank lines", function()
  local result = parser.parse({ "  one", "", "      two", "", "tail", "" }, 10, 2, false)
  t.assert_eq(1, result.levels[10], "first line")
  t.assert_eq(3, result.levels[11], "blank before deeper line")
  t.assert_eq(3, result.levels[12], "deep line")
  t.assert_eq(3, result.levels[13], "blank before dedent")
  t.assert_eq(0, result.levels[14], "dedent target")
  t.assert_eq(0, result.levels[15], "trailing blank")
end)

t:test("dedent-scoped filetypes assign blank lines from the following line", function()
  local result = parser.parse({ "  one", "", "      two", "", "tail" }, 0, 2, true)
  t.assert_eq(3, result.levels[1], "blank before deeper line")
  t.assert_eq(0, result.levels[3], "blank before dedent")
end)

t:test("dedent-scoped filetypes are explicit", function()
  t.assert_true(parser.is_dedent_scoped("python"), "python")
  t.assert_true(parser.is_dedent_scoped("yaml"), "yaml")
  t.assert_false(parser.is_dedent_scoped("lua"), "lua")
end)

t:run()
