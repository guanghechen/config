local harness = require("__test__.support.harness")

local t = harness.new()

vim.o.showmode = false

-- An in-memory clipboard keeps the system one out of the test.
local clipboard = { lines = { "pasted" }, regtype = "v" }
vim.g.clipboard = {
  name = "test",
  copy = {
    ["+"] = function(lines, regtype)
      clipboard = { lines = lines, regtype = regtype }
    end,
    ["*"] = function() end,
  },
  paste = {
    ["+"] = function()
      return { clipboard.lines, clipboard.regtype }
    end,
    ["*"] = function()
      return { {}, "v" }
    end,
  },
  cache_enabled = 0,
}

require("ark.keymap")

---@param line                          string
---@param col                           integer
---@return integer
local function open(line, col)
  local previous = vim.api.nvim_get_current_buf() ---@type integer
  local bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  t:defer(function()
    vim.api.nvim_set_current_buf(previous)
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end)
  vim.api.nvim_set_current_buf(bufnr)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { line })
  vim.api.nvim_win_set_cursor(0, { 1, col })
  return bufnr
end

t:test("Insert mode pastes at the cursor and stays in Insert mode", function()
  open("ab", 0)

  vim.api.nvim_feedkeys(vim.keycode("i<M-v>X<Esc>"), "tx", false)
  t.assert_eq("pastedXab", vim.api.nvim_get_current_line())
end)

t:test("Visual mode replaces the selection and keeps the unnamed register", function()
  open("one two three", 4)
  vim.fn.setreg('"', "kept")

  vim.api.nvim_feedkeys(vim.keycode("viw<M-v>"), "tx", false)
  t.assert_eq("one pasted three", vim.api.nvim_get_current_line())
  t.assert_eq("kept", vim.fn.getreg('"'), "unnamed register")
end)

t:test("Normal mode pastes after the cursor", function()
  open("ab", 0)

  vim.api.nvim_feedkeys(vim.keycode("<M-v>"), "tx", false)
  t.assert_eq("apastedb", vim.api.nvim_get_current_line())
end)

t:run()
