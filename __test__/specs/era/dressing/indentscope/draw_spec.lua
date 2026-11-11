local dressing = require("__test__.support.dressing")
local harness = require("__test__.support.harness")

local t = harness.new()
local Indentscope = dressing.with_indentscope(t)

t:test("draw renders one guide on every scope body line", function()
  local bufnr = dressing.indentscope_buffer(t, { "if ok then", "  one()", "  two()", "end" })
  vim.api.nvim_win_set_cursor(0, { 2, 2 })
  local scope = Indentscope.get_scope(nil, nil, { try_as_border = false })
  Indentscope.draw(scope, { interval = 0 })

  local rows = dressing.indentscope_rows(t)
  t.assert_eq(2, #rows, "guide count")
  t.assert_eq(1, rows[1], "first guide row")
  t.assert_eq(2, rows[2], "second guide row")

  local namespace = vim.api.nvim_get_namespaces()["era.dressing.indentscope"] ---@type integer
  local extmarks = vim.api.nvim_buf_get_extmarks(bufnr, namespace, 0, -1, {}) ---@type table[]
  t.assert_eq(0, #extmarks, "persistent extmark count")
end)

t:test("draw clips guides to the current viewport", function()
  dressing.indentscope_buffer(t, dressing.indented_lines(200))
  vim.api.nvim_win_set_cursor(0, { 101, 2 })
  vim.cmd("normal! zz")
  local visible_top = vim.fn.line("w0") ---@type integer
  local visible_bottom = vim.fn.line("w$") ---@type integer
  local scope = Indentscope.get_scope(nil, nil, { try_as_border = false })
  Indentscope.draw(scope, { interval = 0 })

  local rows = dressing.indentscope_rows(t)
  t.assert_eq(visible_bottom - visible_top + 1, #rows, "viewport guide count")
  t.assert_eq(visible_top - 1, rows[1], "first viewport row")
  t.assert_eq(visible_bottom - 1, rows[#rows], "last viewport row")
  t.assert_true(#rows < scope.body.bottom - scope.body.top + 1, "scope is clipped")
end)

t:test("draw renders only in the active window for a shared buffer", function()
  dressing.indentscope_buffer(t, {
    "function outer()",
    "  if one then",
    "    one()",
    "  end",
    "  if two then",
    "    two()",
    "  end",
    "end",
  })
  local inactive_winnr = vim.api.nvim_get_current_win() ---@type integer
  vim.api.nvim_win_set_cursor(inactive_winnr, { 3, 4 })
  vim.cmd("vsplit")
  local active_winnr = vim.api.nvim_get_current_win() ---@type integer
  t:defer(function()
    if vim.api.nvim_win_is_valid(active_winnr) then
      vim.api.nvim_win_close(active_winnr, true)
    end
  end)
  vim.api.nvim_win_set_cursor(active_winnr, { 6, 4 })

  local scope = Indentscope.get_scope(nil, nil, { try_as_border = false })
  Indentscope.draw(scope, { interval = 0 })
  vim.api.nvim__redraw({ valid = false, flush = true })

  t.assert_eq("╎", dressing.screen_char(active_winnr, 6, 2), "active window guide")
  t.assert_eq(" ", dressing.screen_char(inactive_winnr, 6, 2), "inactive window guide")

  vim.api.nvim_set_current_win(inactive_winnr)
  scope = Indentscope.get_scope(nil, nil, { try_as_border = false })
  Indentscope.draw(scope, { interval = 0 })
  -- Headless scripts have no idle redraw; static frames are not flushed outside the command line.
  vim.api.nvim__redraw({ flush = true })

  t.assert_eq("╎", dressing.screen_char(inactive_winnr, 3, 2), "new active window guide")
  t.assert_eq(" ", dressing.screen_char(active_winnr, 6, 2), "previous active window guide")
end)

t:test("changing scope clears guide rows outside the new body", function()
  dressing.indentscope_buffer(t, { "if ok then", "  one()", "  two()", "  three()", "end" })
  local winnr = vim.api.nvim_get_current_win() ---@type integer

  vim.api.nvim_win_set_cursor(winnr, { 2, 2 })
  local scope = Indentscope.get_scope(nil, nil, { try_as_border = false })
  Indentscope.draw(scope, { interval = 0 })
  vim.api.nvim__redraw({ flush = true })
  t.assert_eq("╎", dressing.screen_char(winnr, 4), "previous guide")

  local narrowed = vim.deepcopy(scope)
  narrowed.body.bottom = 3
  Indentscope.draw(narrowed, { interval = 0 })
  vim.api.nvim__redraw({ flush = true })
  t.assert_eq("╎", dressing.screen_char(winnr, 3), "kept guide")
  t.assert_eq(" ", dressing.screen_char(winnr, 4), "cleared guide")
end)

t:test("scope changes redraw guide rows until the buffer changes", function()
  local bufnr =
    dressing.indentscope_buffer(t, { "if first then", "  first()", "end", "if second then", "  second()", "end" })
  vim.api.nvim_win_set_cursor(0, { 2, 2 })
  Indentscope.draw(Indentscope.get_scope(nil, nil, { try_as_border = false }), { interval = 0 })

  local redraws = {} ---@type table[]
  local original = vim.api.nvim__redraw
  t:patch_table(vim.api, "nvim__redraw", function(options)
    redraws[#redraws + 1] = options
    return original(options)
  end)

  vim.api.nvim_win_set_cursor(0, { 5, 2 })
  Indentscope.draw(Indentscope.get_scope(nil, nil, { try_as_border = false }), { interval = 0 })
  t.assert_eq(2, #redraws, "redraw count")
  t.assert_eq("1:2", table.concat(redraws[1].range or {}, ":"), "previous guide rows")
  t.assert_eq("4:5", table.concat(redraws[2].range or {}, ":"), "current guide rows")

  redraws = {}
  vim.api.nvim_buf_set_lines(bufnr, 0, 0, false, { "-- shifted" })
  vim.api.nvim_win_set_cursor(0, { 3, 2 })
  Indentscope.draw(Indentscope.get_scope(nil, nil, { try_as_border = false }), { interval = 0 })
  t.assert_eq(false, redraws[1].valid, "moved guide rows redraw the window")
end)

t:test("draw skips lines hidden inside a closed fold", function()
  dressing.indentscope_buffer(t, dressing.indented_lines(200))
  vim.api.nvim_set_option_value("foldmethod", "manual", { win = 0 })
  vim.cmd("2,201fold")
  vim.api.nvim_win_set_cursor(0, { 2, 2 })
  vim.cmd("normal! zc")
  local scope = Indentscope.get_scope(nil, nil, { try_as_border = false })
  Indentscope.draw(scope, { interval = 0 })

  local rows = dressing.indentscope_rows(t)
  t.assert_eq(1, #rows, "fold guide count")
  t.assert_eq(1, rows[1], "fold start row")
end)

t:test("draw refreshes when a fold opens or closes", function()
  dressing.indentscope_buffer(t, dressing.indented_lines(100))
  vim.api.nvim_set_option_value("foldmethod", "manual", { win = 0 })
  vim.cmd("2,101fold")
  vim.api.nvim_win_set_cursor(0, { 2, 2 })
  vim.cmd("normal! zc")
  local scope = Indentscope.get_scope(nil, nil, { try_as_border = false })
  Indentscope.draw(scope, { interval = 0 })

  local function guide_count()
    return #dressing.indentscope_rows(t)
  end

  t.assert_eq(1, guide_count(), "closed fold")
  vim.cmd("normal! zo")
  vim.cmd("redraw")
  t.wait_until(function()
    return guide_count() > 1
  end, 5000, "opened fold redraw")

  vim.cmd("normal! zc")
  vim.cmd("redraw")
  t.wait_until(function()
    return guide_count() == 1
  end, 5000, "closed fold redraw")
end)

t:test("draw suppresses a scope spanning the whole indented buffer", function()
  dressing.indentscope_buffer(t, { "  one()", "  two()", "  three()" })
  vim.api.nvim_win_set_cursor(0, { 2, 2 })
  local scope = Indentscope.get_scope(nil, nil, { try_as_border = false })
  Indentscope.draw(scope, { interval = 0 })

  t.assert_eq(-1, scope.border.indent, "imaginary border indent")
  t.assert_eq(0, #dressing.indentscope_rows(t), "guide count")
end)

t:run()
