local harness = require("__test__.support.harness")

local t = harness.new()

t:patch_global("stl", { icon = { fillchars = {}, listchars = {} } })
assert(loadfile("lua/ark/option.lua"))()

t:test(">> shifts a line that starts with #", function()
  t:buffer({ "# note", "value = 1" }, { current = true })

  vim.cmd("normal! gg>j")
  t.assert_eq(vim.o.shiftwidth, vim.fn.indent(1), "the # line")
  t.assert_eq(vim.o.shiftwidth, vim.fn.indent(2), "the other line")
end)

t:test("a typed # keeps the indent of the line above where no indentexpr applies", function()
  t:buffer({ "  value = 1" }, { current = true })

  vim.api.nvim_feedkeys(vim.keycode("o# note<Esc>"), "tx", false)
  t.assert_eq(2, vim.fn.indent(2), "indent of the new line")
end)

t:run()
