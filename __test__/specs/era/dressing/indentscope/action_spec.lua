local dressing = require("__test__.support.dressing")
local harness = require("__test__.support.harness")

local t = harness.new()
local Indentscope = dressing.with_indentscope(t)

t:test("move_cursor chooses border or body", function()
  dressing.indentscope_buffer(t, { "if ok then", "  one()", "  two()", "end" })
  vim.api.nvim_win_set_cursor(0, { 2, 2 })
  local scope = Indentscope.get_scope(nil, nil, { try_as_border = false })

  Indentscope.move_cursor("bottom", true, scope)
  t.assert_eq(4, vim.api.nvim_win_get_cursor(0)[1], "bottom border")

  Indentscope.move_cursor("top", false, scope)
  t.assert_eq(2, vim.api.nvim_win_get_cursor(0)[1], "top body")
end)

t:test("inner textobject selects the scope body linewise", function()
  dressing.indentscope_buffer(t, { "if ok then", "  one()", "  two()", "end" })
  vim.api.nvim_win_set_cursor(0, { 2, 2 })
  Indentscope.textobject(false)
  vim.cmd("normal! y")

  t.assert_eq("  one()\n  two()\n", vim.fn.getreg('"'), "yanked scope")
end)

t:run()
