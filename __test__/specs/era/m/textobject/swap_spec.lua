local harness = require("__test__.support.harness")
local Runtime = require("__test__.fixtures.era.m.textobject.runtime")
local Swap = require("era.m.textobject.swap")
local t = harness.new("era.m.textobject.swap")
local Textobject = Runtime.setup(t)

vim.keymap.set("n", "<F5>", function()
  Textobject.swap_parameter(1)
end)
vim.keymap.set("n", "<F6>", function()
  Textobject.swap_parameter(-1)
end)

t:test("pure swap plans preserve separators and rotate by count", function()
  local lines = { "f(a, longer, z)" }
  local ranges = {
    { 0, 2, 0, 3, container = "arguments" },
    { 0, 5, 0, 11, container = "arguments" },
    { 0, 13, 0, 14, container = "arguments" },
  }
  local edit = assert(Swap.plan(lines, ranges, { 0, 2 }, 1, 2))
  t.assert_eq("longer, z, a", table.concat(edit.lines, "\n"))
  t.assert_eq(vim.inspect({ 1, 13 }), vim.inspect(edit.cursor))
  t.assert_nil(Swap.plan(lines, ranges, { 0, 2 }, 1, 3), "unavailable count is not partially applied")
  t.assert_nil(Swap.plan(lines, ranges, { 0, 0 }, 1, 1), "cursor must be inside a parameter")
end)

t:test("parameter swaps are one undo step and dot-repeat at the moved parameter", function()
  Runtime.buffer(t, { "f(short, much_longer, last)" })
  vim.api.nvim_win_set_cursor(0, { 1, 3 })
  Runtime.feed("<F5>")
  t.assert_eq("f(much_longer, short, last)", vim.api.nvim_get_current_line())
  Runtime.feed(".")
  t.assert_eq("f(much_longer, last, short)", vim.api.nvim_get_current_line())
  Runtime.feed("u")
  t.assert_eq("f(much_longer, short, last)", vim.api.nvim_get_current_line())
  Runtime.feed("u")
  t.assert_eq("f(short, much_longer, last)", vim.api.nvim_get_current_line())
  Runtime.feed("<C-r>")
  t.assert_eq("f(much_longer, short, last)", vim.api.nvim_get_current_line())
end)

t:test("backward swaps and counts remain inside one argument list", function()
  Runtime.buffer(t, { "f(a, bb, ccc)" })
  vim.api.nvim_win_set_cursor(0, { 1, 10 })
  Runtime.feed("2<F6>")
  t.assert_eq("f(ccc, a, bb)", vim.api.nvim_get_current_line())
  Runtime.feed("u")
  t.assert_eq("f(a, bb, ccc)", vim.api.nvim_get_current_line())
end)

t:test("multiline Unicode arguments preserve bytes, punctuation, and cursor placement", function()
  Runtime.buffer(t, { 'f("中文", nested(', '  "🙂", 2), last)' })
  vim.api.nvim_win_set_cursor(0, { 1, 3 })
  Runtime.feed("<F5>")
  t.assert_eq(
    'f(nested(\n  "🙂", 2), "中文", last)',
    table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, true), "\n")
  )
  t.assert_eq('"中文"', Runtime.text(assert(Textobject.find("i", "a"))))
  Runtime.feed("u")
  t.assert_eq(
    'f("中文", nested(\n  "🙂", 2), last)',
    table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, true), "\n")
  )
end)

t:test("swaps never cross nested or neighboring calls", function()
  Runtime.buffer(t, { "f(a, g(b, c)); h(d, e)" })
  vim.api.nvim_win_set_cursor(0, { 1, 10 })
  Runtime.feed("<F5>")
  t.assert_eq("f(a, g(b, c)); h(d, e)", vim.api.nvim_get_current_line())
  vim.api.nvim_win_set_cursor(0, { 1, 5 })
  Runtime.feed("<F5>")
  t.assert_eq("f(a, g(b, c)); h(d, e)", vim.api.nvim_get_current_line())
end)

t:test("unavailable counts and readonly buffers are unchanged", function()
  local bufnr = Runtime.buffer(t, { "f(a, bb)" })
  vim.api.nvim_win_set_cursor(0, { 1, 2 })
  Runtime.feed("2<F5>")
  t.assert_eq("f(a, bb)", vim.api.nvim_get_current_line())
  vim.api.nvim_set_option_value("readonly", true, { buf = bufnr })
  Runtime.feed("<F5>")
  t.assert_eq("f(a, bb)", vim.api.nvim_get_current_line())
end)

t:run()
