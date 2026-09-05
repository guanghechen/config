--- Run with: nvim -l __test__/run.lua __test__/specs/era/dressing/indentline/parser_spec.lua

local harness = require("__test__.support.harness")

local t = harness.new("era.dressing.indentline.parser")
local parser = require("era.dressing.indentline.parser")

local options = {
  shiftwidth = 2,
  tabstop = 8,
  vartabstops = {},
} ---@type era.dressing.indentline.parser.IOptions

t:test("indent level expands tabs using visual tabstops", function()
  local level, is_all_whitespace, whitespace_width, whitespace = parser.get_indent_level("\tvalue", options)
  t.assert_eq(4, level, "indent level")
  t.assert_false(is_all_whitespace, "non-blank line")
  t.assert_eq(8, whitespace_width, "whitespace width")
  t.assert_eq("\t", whitespace, "source whitespace")
end)

t:test("variable tabstops repeat the final width", function()
  local level, _, whitespace_width = parser.get_indent_level("\t\t\tvalue", {
    shiftwidth = 2,
    tabstop = 8,
    vartabstops = { 4, 2 },
  })
  t.assert_eq(4, level, "indent level")
  t.assert_eq(8, whitespace_width, "whitespace width")
end)

t:test("buffer options preserve shiftwidth one and parse vartabstop", function()
  local bufnr = vim.api.nvim_create_buf(false, false) ---@type integer
  vim.api.nvim_set_option_value("shiftwidth", 1, { buf = bufnr })
  vim.api.nvim_set_option_value("tabstop", 8, { buf = bufnr })
  vim.api.nvim_set_option_value("vartabstop", "4,2", { buf = bufnr })

  local resolved = parser.get_options(bufnr)
  t.assert_eq(1, resolved.shiftwidth, "shiftwidth")
  t.assert_eq(8, resolved.tabstop, "tabstop")
  t.assert_eq(2, #resolved.vartabstops, "vartabstop count")
  t.assert_eq(4, resolved.vartabstops[1], "first vartabstop")
  t.assert_eq(2, resolved.vartabstops[2], "repeated vartabstop")

  vim.api.nvim_set_option_value("shiftwidth", 0, { buf = bufnr })
  t.assert_eq(4, parser.get_options(bufnr).shiftwidth, "vartabstop-derived shiftwidth")

  vim.api.nvim_buf_delete(bufnr, { force = true })
end)

t:test("non-dedent scopes preserve the deeper adjacent indent on blank lines", function()
  local result = parser.parse({ "  one", "", "      two", "", "tail", "" }, 10, options, false)
  t.assert_eq(1, result.levels[10], "first line")
  t.assert_eq(3, result.levels[11], "blank before deeper line")
  t.assert_eq(3, result.levels[12], "deep line")
  t.assert_eq(3, result.levels[13], "blank before dedent")
  t.assert_eq(0, result.levels[14], "dedent target")
  t.assert_eq(0, result.levels[15], "trailing blank")
  t.assert_true(result.blank_rows[11], "blank row metadata")
  t.assert_true(result.blank_rows[15], "trailing blank metadata")
end)

t:test("dedent-scoped filetypes assign blank lines from the following line", function()
  local result = parser.parse({ "  one", "", "      two", "", "tail" }, 0, options, true)
  t.assert_eq(3, result.levels[1], "blank before deeper line")
  t.assert_eq(0, result.levels[3], "blank before dedent")
end)

t:test("boundary context resolves blank runs outside the parsed range", function()
  local non_dedent = parser.parse({ "", "" }, 10, options, false, {
    previous_level = 3,
    following_level = 1,
  })
  t.assert_eq(3, non_dedent.levels[10], "non-dedent first blank")
  t.assert_eq(3, non_dedent.levels[11], "non-dedent last blank")

  local dedent = parser.parse({ "", "" }, 10, options, true, {
    previous_level = 3,
    following_level = 1,
  })
  t.assert_eq(1, dedent.levels[10], "dedent first blank")
  t.assert_eq(1, dedent.levels[11], "dedent last blank")
end)

t:test("dedent-scoped filetypes are explicit", function()
  t.assert_true(parser.is_dedent_scoped("python"), "python")
  t.assert_true(parser.is_dedent_scoped("yaml"), "yaml")
  t.assert_true(parser.is_dedent_scoped("automake"), "automake")
  t.assert_true(parser.is_dedent_scoped("make"), "make")
  t.assert_false(parser.is_dedent_scoped("lua"), "lua")
  t.assert_false(parser.is_dedent_scoped("rust"), "rust")
  t.assert_false(parser.is_dedent_scoped("makefile"), "makefile")
  t.assert_false(parser.is_dedent_scoped("text"), "text")
end)

t:run()
