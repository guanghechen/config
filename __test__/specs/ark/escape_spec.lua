local harness = require("__test__.support.harness")
local t = harness.new()

require("ark.keymap")

t:test("escape skips unused snippets and stops an active native session", function()
  local escape = vim.fn.maparg("<Esc>", "n", false, true).callback ---@type (fun(): string)|nil
  t.assert_nil(package.loaded["vim.snippet"], "cold snippet module")
  t.assert_eq("<esc>", assert(escape)(), "mapped key")
  t.assert_nil(package.loaded["vim.snippet"], "unused snippet module remains unloaded")

  local snippet = require("vim.snippet")
  t:buffer({ "" }, { current = true })
  t:defer(snippet.stop)
  snippet.expand("${1:word}$0")
  t.assert_true(snippet.active(), "native snippet session")

  t.assert_eq("<esc>", escape(), "mapped key")
  t.assert_false(snippet.active(), "session stopped")
  t.assert_eq("word", vim.api.nvim_get_current_line(), "snippet text preserved")
end)

t:run()
