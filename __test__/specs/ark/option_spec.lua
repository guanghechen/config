local harness = require("__test__.support.harness")

local t = harness.new()

t:patch_global("stl", { icon = { fillchars = {}, listchars = {} } })
assert(loadfile("lua/ark/option.lua"))()

---@param lines                         string[]
---@return integer
local function open(lines)
  local previous = vim.api.nvim_get_current_buf() ---@type integer
  local bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  t:defer(function()
    vim.api.nvim_set_current_buf(previous)
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end)
  vim.api.nvim_set_current_buf(bufnr)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  return bufnr
end

t:test(">> shifts a line that starts with #", function()
  open({ "# note", "value = 1" })

  vim.cmd("normal! gg>j")
  t.assert_eq(vim.o.shiftwidth, vim.fn.indent(1), "the # line")
  t.assert_eq(vim.o.shiftwidth, vim.fn.indent(2), "the other line")
end)

t:test("a typed # keeps the indent of the line above where no indentexpr applies", function()
  open({ "  value = 1" })

  vim.api.nvim_feedkeys(vim.keycode("o# note<Esc>"), "tx", false)
  t.assert_eq(2, vim.fn.indent(2), "indent of the new line")
end)

t:run()
