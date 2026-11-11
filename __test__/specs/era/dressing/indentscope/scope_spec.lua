local dressing = require("__test__.support.dressing")
local harness = require("__test__.support.harness")

local t = harness.new()
local Indentscope = dressing.with_indentscope(t)

t:test("try_as_border resolves the nested scope from its header", function()
  dressing.indentscope_buffer(t, { "function outer()", "  if ok then", "    call()", "  end", "end" })
  vim.api.nvim_win_set_cursor(0, { 2, 2 })
  local scope = Indentscope.get_scope()

  t.assert_eq(3, scope.reference.line, "reference line")
  t.assert_eq(3, scope.body.top, "body top")
  t.assert_eq(3, scope.body.bottom, "body bottom")
  t.assert_eq(2, scope.border.top, "border top")
  t.assert_eq(4, scope.border.bottom, "border bottom")
  t.assert_eq(2, scope.border.indent, "border indent")
end)

t:test("border policy controls blank lines at scope edges", function()
  dressing.indentscope_buffer(t, { "function outer()", "", "    call()", "", "  end" })
  vim.api.nvim_win_set_cursor(0, { 3, 4 })

  local both = Indentscope.get_scope(nil, nil, { border = "both", try_as_border = false })
  local top = Indentscope.get_scope(nil, nil, { border = "top", try_as_border = false })
  local bottom = Indentscope.get_scope(nil, nil, { border = "bottom", try_as_border = false })
  local none = Indentscope.get_scope(nil, nil, { border = "none", try_as_border = false })

  t.assert_eq(2, both.body.top, "both top")
  t.assert_eq(4, both.body.bottom, "both bottom")
  t.assert_eq(2, top.body.top, "top top")
  t.assert_eq(3, top.body.bottom, "top bottom")
  t.assert_eq(3, bottom.body.top, "bottom top")
  t.assert_eq(4, bottom.body.bottom, "bottom bottom")
  t.assert_eq(3, none.body.top, "none top")
  t.assert_eq(3, none.body.bottom, "none bottom")
end)

t:test("scope scans beyond the former line limit", function()
  local lines = {} ---@type string[]
  for index = 1, 8193 do
    lines[index] = "  line"
  end

  dressing.indentscope_buffer(t, lines)
  vim.api.nvim_win_set_cursor(0, { 4097, 2 })
  local scope = Indentscope.get_scope(nil, nil, { try_as_border = false })

  t.assert_eq(1, scope.body.top, "scope top")
  t.assert_eq(8193, scope.body.bottom, "scope bottom")
end)

t:test("scope cache reuses unchanged boundaries and invalidates on edits", function()
  local bufnr = dressing.indentscope_buffer(t, dressing.indented_lines(200))
  vim.api.nvim_win_set_cursor(0, { 150, 2 })
  local first = Indentscope.get_scope(nil, nil, { try_as_border = false })
  t.assert_eq(2, first.body.top, "initial scope top")
  t.assert_eq(201, first.body.bottom, "initial scope bottom")

  local original_indent = vim.fn.indent
  local indent_calls = 0 ---@type integer
  t:patch_table(vim.fn, "indent", function(...)
    indent_calls = indent_calls + 1
    return original_indent(...)
  end)

  vim.api.nvim_win_set_cursor(0, { 151, 2 })
  local reused = Indentscope.get_scope(nil, nil, { try_as_border = false })
  t.assert_eq(2, reused.body.top, "reused scope top")
  t.assert_eq(201, reused.body.bottom, "reused scope bottom")
  t.assert_eq(1, indent_calls, "cached indent reads")

  indent_calls = 0
  vim.api.nvim_buf_set_lines(bufnr, 119, 120, false, { "break" })
  local invalidated = Indentscope.get_scope(nil, nil, { try_as_border = false })
  t.assert_eq(121, invalidated.body.top, "invalidated scope top")
  t.assert_eq(201, invalidated.body.bottom, "invalidated scope bottom")
  t.assert_true(indent_calls > 50, "edit forces a full scan")
end)

t:run()
