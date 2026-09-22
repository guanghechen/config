local harness = require("__test__.support.harness")
local t = harness.new("ark.escape")

require("ark.keymap")

t:test("escape skips unused snippets and stops an active native session", function()
  local escape = nil ---@type (fun(): string)|nil
  for _, keymap in ipairs(vim.api.nvim_get_keymap("n")) do
    if keymap.lhs == "<Esc>" then
      escape = keymap.callback
      break
    end
  end
  t.assert_nil(package.loaded["vim.snippet"], "cold snippet module")
  t.assert_eq("<esc>", assert(escape)(), "mapped key")
  t.assert_nil(package.loaded["vim.snippet"], "unused snippet module remains unloaded")

  local snippet = require("vim.snippet")
  local previous = vim.api.nvim_get_current_buf() ---@type integer
  local bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  t:defer(function()
    snippet.stop()
    vim.api.nvim_set_current_buf(previous)
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end)
  vim.api.nvim_set_current_buf(bufnr)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "" })
  snippet.expand("${1:word}$0")
  t.assert_true(snippet.active(), "native snippet session")

  t.assert_eq("<esc>", escape(), "mapped key")
  t.assert_false(snippet.active(), "session stopped")
  t.assert_eq("word", vim.api.nvim_get_current_line(), "snippet text preserved")
end)

t:run()
