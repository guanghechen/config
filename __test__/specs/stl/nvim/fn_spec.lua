local harness = require("__test__.support.harness")
local fn = require("stl.nvim.fn")
local t = harness.new()
vim.o.showmode = false

t:test("noremap false permits remapping and explicit overrides take priority", function()
  t:defer(function()
    vim.keymap.del("n", "<F7>")
    vim.keymap.del("n", "<F8>")
  end)
  local remapped = false ---@type boolean
  vim.keymap.set("n", "<F8>", function()
    remapped = true
  end)
  local keymaps = { { modes = { "n" }, key = "<F7>", callback = "<F8>", noremap = false } }
  fn.bindkeys(keymaps, {})
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<F7>", true, false, true), "xt", false)
  t.assert_true(remapped, "<F7> runs the map of <F8>")
  fn.bindkeys(keymaps, { noremap = true })
  t.assert_eq(1, vim.fn.maparg("<F7>", "n", false, true).noremap)
  keymaps[1].noremap = true
  fn.bindkeys(keymaps, { noremap = false })
  t.assert_eq(0, vim.fn.maparg("<F7>", "n", false, true).noremap)
end)

---Leaves Insert mode as closing a float does: a mapping of the float returns to a window showing `line`, with the
---cursor at byte `col`, stops Insert mode there and then runs `move` when given.
---@param line                          string
---@param col                           integer
---@param move                          ?fun(winnr: integer): nil
---@return integer col The byte column the cursor ends at.
local function leave_insert(line, col, move)
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  vim.api.nvim_win_set_buf(winnr, t:buffer({ line }))
  vim.api.nvim_win_set_cursor(winnr, { 1, col })
  local float_bufnr = t:buffer()
  local float =
    vim.api.nvim_open_win(float_bufnr, true, { relative = "editor", row = 1, col = 1, width = 9, height = 1 })
  vim.keymap.set("i", "<F2>", function()
    vim.api.nvim_win_close(float, true)
    vim.api.nvim_set_current_win(winnr)
    fn.stop_insert_in_place()
    if move then
      move(winnr)
    end
  end, { buf = float_bufnr })
  vim.api.nvim_feedkeys(vim.keycode("i<F2>"), "xt", false)
  return vim.api.nvim_win_get_cursor(winnr)[2]
end

t:test("stop_insert_in_place keeps the cursor however many bytes the character before it takes", function()
  t.assert_eq(2, leave_insert("abcd", 2), "ASCII")
  t.assert_eq(3, leave_insert("你好世界", 3), "CJK")
  t.assert_eq(3, leave_insert("héllo", 3), "precomposed é")
  t.assert_eq(5, leave_insert("a😀b", 5), "emoji")
  t.assert_eq(3, leave_insert("e\204\129x", 3), "e with a composing acute accent")
end)

t:test("stop_insert_in_place keeps the cursor on a line with a NUL byte", function()
  vim.v.errmsg = ""
  t.assert_eq(3, leave_insert("abcd\0z", 3), "the cursor stays on d")
  t.assert_nil(vim.v.errmsg:match("E1174"), vim.v.errmsg)
end)

t:test("stop_insert_in_place keeps the cursor where the caller moves it", function()
  ---@param col                         integer
  ---@return fun(winnr: integer): nil
  local function move_to(col)
    return function(winnr)
      vim.api.nvim_win_set_cursor(winnr, { 1, col })
    end
  end
  t.assert_eq(0, leave_insert("abcd", 2, move_to(0)), "to the line start")
  t.assert_eq(1, leave_insert("abcd", 2, move_to(1)), "one character left")
  t.assert_eq(3, leave_insert("abcd", 1, move_to(3)), "to the right")
  t.assert_eq(3, leave_insert("你好世界", 6, move_to(3)), "one CJK character left")
end)

t:test("stop_insert_in_place under i_CTRL-O leaves the step back of a later Insert mode alone", function()
  local bufnr = t:buffer({ "abcdef" })
  vim.api.nvim_win_set_buf(0, bufnr)
  vim.api.nvim_win_set_cursor(0, { 1, 3 })
  vim.keymap.set("n", "<F3>", fn.stop_insert_in_place, { buf = bufnr })
  vim.api.nvim_feedkeys(vim.keycode("i<C-o><F3>i<Esc>"), "xt", false)
  t.assert_eq(2, vim.api.nvim_win_get_cursor(0)[2], "the later <Esc> steps back")
end)

t:test("stop_insert_in_place undoes the step back in the window it happened in", function()
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  local bufnr = t:buffer({ "abcdef" }, { current = true })
  vim.api.nvim_win_set_cursor(winnr, { 1, 3 })
  local other = t:window(t:buffer({ "0123456789" }), { split = "right" })
  -- A hook defined before the handlers of the helper moves to another window when Insert mode ends.
  local augroup = vim.api.nvim_create_augroup("stop_insert_in_place_spec", {}) ---@type integer
  t:defer(function()
    vim.api.nvim_del_augroup_by_id(augroup)
  end)
  vim.api.nvim_create_autocmd("InsertLeave", {
    group = augroup,
    once = true,
    callback = function()
      vim.api.nvim_set_current_win(other)
    end,
  })
  vim.keymap.set("i", "<F2>", fn.stop_insert_in_place, { buf = bufnr })
  vim.api.nvim_feedkeys(vim.keycode("i<F2>"), "xt", false)
  t.assert_eq(3, vim.api.nvim_win_get_cursor(winnr)[2], "the step back is undone where it happened")
  t.assert_eq(0, vim.api.nvim_win_get_cursor(other)[2], "the other window keeps its cursor")
end)

t:run()
