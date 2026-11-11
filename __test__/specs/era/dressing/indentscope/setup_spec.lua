local dressing = require("__test__.support.dressing")
local harness = require("__test__.support.harness")

local t = harness.new()
local Indentscope = dressing.with_indentscope(t)

t:test("init keeps rendering and actions lazy", function()
  t.assert_nil(package.loaded["era.dressing.indentscope.draw"], "draw loaded during init")
  t.assert_nil(package.loaded["era.dressing.indentscope.action"], "action loaded during init")
end)

t:test("eligibility is owned by indentscope", function()
  local bufnr = dressing.indentscope_buffer(t, { "if ok then", "  one()", "end" })
  t.assert_true(Indentscope.is_enabled(bufnr), "source buffer")

  for _, filetype in ipairs({ "", stl.filetype.BIGFILE, stl.filetype.BOARD, "diff" }) do
    vim.api.nvim_set_option_value("filetype", filetype, { buf = bufnr })
    t.assert_false(Indentscope.is_enabled(bufnr), filetype == "" and "empty filetype" or filetype)
  end

  vim.api.nvim_set_option_value("filetype", "lua", { buf = bufnr })
  vim.api.nvim_set_option_value("buftype", "prompt", { buf = bufnr })
  t.assert_false(Indentscope.is_enabled(bufnr), "prompt buffer")
end)

t:test("excluded filetype suppresses drawing", function()
  local bufnr = dressing.indentscope_buffer(t, { "if ok then", "  one()", "end" })
  vim.api.nvim_win_set_cursor(0, { 2, 2 })
  local scope = Indentscope.get_scope(nil, nil, { try_as_border = false })
  vim.api.nvim_set_option_value("filetype", stl.filetype.BOARD, { buf = bufnr })
  Indentscope.draw(scope, { interval = 0 })

  t.assert_eq(0, #dressing.indentscope_rows(t), "guide count")
end)

t:test("FileType immediately removes an ineligible scope", function()
  local bufnr = dressing.indentscope_buffer(t, { "if ok then", "  one()", "end" })
  Indentscope.dressing()
  vim.api.nvim_win_set_cursor(0, { 2, 2 })
  local scope = Indentscope.get_scope(nil, nil, { try_as_border = false })
  Indentscope.draw(scope, { interval = 0 })
  t.assert_eq(1, #dressing.indentscope_rows(t), "eligible guide count")

  vim.api.nvim_set_option_value("filetype", stl.filetype.BOARD, { buf = bufnr })
  t.assert_eq(0, #dressing.indentscope_rows(t), "ineligible guide count")
end)

t:test("hidden FileType events preserve the active scope", function()
  dressing.indentscope_buffer(t, { "if ok then", "  one()", "end" })
  Indentscope.dressing()
  vim.api.nvim_win_set_cursor(0, { 2, 2 })
  local scope = Indentscope.get_scope(nil, nil, { try_as_border = false })
  Indentscope.draw(scope, { interval = 0 })
  t.assert_eq(1, #dressing.indentscope_rows(t), "active guide count")

  local hidden_bufnr = t:buffer() ---@type integer
  vim.api.nvim_set_option_value("filetype", stl.filetype.BOARD, { buf = hidden_bufnr })
  t.assert_eq(1, #dressing.indentscope_rows(t), "guide count after hidden FileType")
end)

t:test("excluded CursorMoved skips scope computation", function()
  local bufnr = dressing.indentscope_buffer(t, { "  one()", "  two()" })
  local Scope = require("era.dressing.indentscope.scope")
  local calls = 0 ---@type integer
  t:patch_table(Scope, "get", function()
    calls = calls + 1
    error("disabled scope computation")
  end)

  vim.api.nvim_set_option_value("filetype", stl.filetype.BOARD, { buf = bufnr })
  Indentscope.dressing()
  vim.api.nvim_exec_autocmds("CursorMoved", { modeline = false })

  t.assert_eq(0, calls, "scope calls")
end)

t:test("window and buffer entry refresh the active scope", function()
  dressing.indentscope_buffer(t, { "if ok then", "  one()", "end" })
  local Scope = require("era.dressing.indentscope.scope")
  local original = Scope.get
  local calls = 0 ---@type integer
  t:patch_table(Scope, "get", function(...)
    calls = calls + 1
    return original(...)
  end)

  Indentscope.dressing()
  vim.api.nvim_exec_autocmds("WinEnter", { modeline = false })
  vim.api.nvim_exec_autocmds("BufWinEnter", { modeline = false })

  t.assert_eq(2, calls, "scope calls")
end)

t:test("Insert submode changes skip scope computation", function()
  dressing.indentscope_buffer(t, { "if ok then", "  one()", "end" })
  local Scope = require("era.dressing.indentscope.scope")
  local original = Scope.get
  local calls = 0 ---@type integer
  t:patch_table(Scope, "get", function(...)
    calls = calls + 1
    return original(...)
  end)

  Indentscope.dressing()
  for _, transition in ipairs({ "i:ic", "ic:i", "ix:ic" }) do
    vim.api.nvim_exec_autocmds("ModeChanged", { pattern = transition, modeline = false })
  end
  t.assert_eq(0, calls, "scope calls within Insert mode")

  vim.api.nvim_exec_autocmds("ModeChanged", { pattern = "ic:n", modeline = false })
  t.assert_eq(1, calls, "scope calls on leaving Insert mode")
end)

t:test("WinScrolled updates layout without recomputing scope", function()
  dressing.indentscope_buffer(t, { "if ok then", "  one()", "  two()", "end" })
  vim.api.nvim_win_set_cursor(0, { 2, 2 })
  Indentscope.draw(Indentscope.get_scope(nil, nil, { try_as_border = false }), { interval = 0 })

  local Scope = require("era.dressing.indentscope.scope")
  local calls = 0 ---@type integer
  t:patch_table(Scope, "get", function()
    calls = calls + 1
    error("WinScrolled recomputed scope")
  end)

  Indentscope.dressing()
  vim.api.nvim_exec_autocmds("WinScrolled", { modeline = false })

  t.assert_eq(0, calls, "scope calls")
end)

t:test("WinScrolled keeps a finished scope without redrawing the window", function()
  dressing.indentscope_buffer(t, dressing.indented_lines(200))
  vim.api.nvim_win_set_cursor(0, { 101, 2 })
  vim.cmd("normal! zz")
  Indentscope.draw(Indentscope.get_scope(nil, nil, { try_as_border = false }), { interval = 0 })
  Indentscope.dressing()

  local redraws = 0 ---@type integer
  local original = vim.api.nvim__redraw
  t:patch_table(vim.api, "nvim__redraw", function(options)
    redraws = redraws + 1
    return original(options)
  end)
  vim.cmd("normal! 20" .. vim.keycode("<C-e>"))
  vim.api.nvim_exec_autocmds("WinScrolled", { modeline = false })
  t.assert_eq(0, redraws, "redraw requests")

  local rows = dressing.indentscope_rows(t)
  t.assert_eq(vim.fn.line("w0") - 1, rows[1], "first guide row")
  t.assert_eq(vim.fn.line("w$") - 1, rows[#rows], "last guide row")
end)

t:test("an edit that keeps the scope and every row in place redraws nothing", function()
  local bufnr = dressing.indentscope_buffer(t, { "if ok then", "  one()", "  two()", "end", "tail" })
  vim.api.nvim_win_set_cursor(0, { 2, 2 })
  Indentscope.draw(Indentscope.get_scope(nil, nil, { try_as_border = false }), { interval = 0 })
  Indentscope.dressing()

  local redraws = {} ---@type table[]
  local original = vim.api.nvim__redraw
  t:patch_table(vim.api, "nvim__redraw", function(options)
    redraws[#redraws + 1] = options
    return original(options)
  end)
  vim.api.nvim_buf_set_text(bufnr, 1, 7, 1, 7, { " -- note" })
  vim.api.nvim_exec_autocmds("TextChanged", { modeline = false })
  t.assert_eq(0, #redraws, "redraw requests")
  t.assert_eq("1,2", table.concat(dressing.indentscope_rows(t), ","), "guide rows")

  redraws = {}
  vim.api.nvim_buf_set_lines(bufnr, 2, 2, false, { "  three()" })
  vim.api.nvim_exec_autocmds("TextChanged", { modeline = false })
  t.assert_true(#redraws > 0, "moved rows redraw")
  t.assert_eq("1,2,3", table.concat(dressing.indentscope_rows(t), ","), "guide rows after the insert")
end)

t:run()
