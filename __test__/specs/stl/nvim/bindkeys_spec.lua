local harness = require("__test__.support.harness")
local fn = require("stl.nvim.fn")
local t = harness.new("stl.nvim.bindkeys")

t:test("noremap false permits remapping and explicit overrides take priority", function()
  t:defer(function()
    vim.keymap.del("n", "<F7>")
    vim.keymap.del("n", "<F8>")
  end)
  vim.keymap.set("n", "<F8>", function()
    vim.g.textobject_bindkeys_result = true
  end)
  local keymaps = { { modes = { "n" }, key = "<F7>", callback = "<F8>", noremap = false } }
  fn.bindkeys(keymaps, {})
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<F7>", true, false, true), "xt", false)
  t.assert_true(vim.g.textobject_bindkeys_result)
  vim.g.textobject_bindkeys_result = nil
  fn.bindkeys(keymaps, { noremap = true })
  t.assert_eq(1, vim.fn.maparg("<F7>", "n", false, true).noremap)
  keymaps[1].noremap = true
  fn.bindkeys(keymaps, { noremap = false })
  t.assert_eq(0, vim.fn.maparg("<F7>", "n", false, true).noremap)
end)

t:run()
