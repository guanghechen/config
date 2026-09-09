local harness = require("__test__.support.harness")
local Runtime = require("__test__.fixtures.era.m.textobject.runtime")
local Find = require("era.m.textobject.find")
local t = harness.new("era.m.textobject.eligibility")
local Textobject = Runtime.setup(t)
local Filetype = require("stl.filetype")

t:test("ordinary buffers retain textobjects before filetype detection and in prose or diff files", function()
  local bufnr = Runtime.buffer(t, { "(  body  )" })
  vim.api.nvim_set_option_value("buftype", "", { buf = bufnr })
  for _, filetype in ipairs({ "", "lua", "text", "diff", Filetype.GITCOMMIT }) do
    vim.api.nvim_set_option_value("filetype", filetype, { buf = bufnr })
    vim.api.nvim_win_set_cursor(0, { 1, 4 })
    Runtime.feed("yi(")
    t.assert_eq("body", vim.fn.getreg('"'), filetype .. " selection")
  end
end)

t:test("notepads and source scratch buffers keep their custom objects", function()
  local bufnr = Runtime.buffer(t, { "(  body  )" })
  t.assert_eq("nofile", vim.api.nvim_get_option_value("buftype", { buf = bufnr }))
  for _, filetype in ipairs({ Filetype.NOTEPAD, "markdown", "lua" }) do
    vim.api.nvim_set_option_value("filetype", filetype, { buf = bufnr })
    vim.api.nvim_win_set_cursor(0, { 1, 4 })
    Runtime.feed("yi(")
    t.assert_eq("body", vim.fn.getreg('"'), filetype .. " scratch selection")
  end
end)

t:test("UI metadata preserves native selections without a buffer flag", function()
  local bufnr = Runtime.buffer(t, { "(  body  )" })
  for _, filetype in ipairs({
    Filetype.BOARD,
    Filetype.UX_PICKER_FINDER,
    Filetype.UX_PICKER_PREVIEW,
    Filetype.UX_PICKER_RESULT,
    Filetype.UX_SEARCHER_FINDER,
    Filetype.UX_SEARCHER_PREVIEW,
    Filetype.UX_SEARCHER_RESULT,
    Filetype.DIFFVIEW_CHANGES,
    "", -- Searcher finder/replacer buffers have no filetype.
    "diff", -- Git hunk preview uses a scratch diff buffer.
  }) do
    vim.api.nvim_set_option_value("filetype", filetype, { buf = bufnr })
    vim.api.nvim_win_set_cursor(0, { 1, 4 })
    t.assert_nil(Textobject.find("i", "("), filetype .. " provider")
    Runtime.feed("yi(")
    t.assert_eq("  body  ", vim.fn.getreg('"'), filetype .. " native selection")
  end
end)

t:test("readonly and nonmodifiable source buffers remain selectable but cannot exchange parameters", function()
  local bufnr = Runtime.buffer(t, { "f(first, second)" })
  for _, buftype in ipairs({ "", "nowrite", "acwrite", "nofile" }) do
    vim.api.nvim_set_option_value("buftype", buftype, { buf = bufnr })
    vim.api.nvim_set_option_value("readonly", true, { buf = bufnr })
    vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })
    vim.api.nvim_win_set_cursor(0, { 1, 4 })
    Runtime.feed("yi(")
    t.assert_eq("first, second", vim.fn.getreg('"'), buftype .. " readonly selection")
    Textobject.swap_operator("")
    t.assert_eq("f(first, second)", vim.api.nvim_get_current_line(), buftype .. " readonly exchange")
  end
end)

t:test("special buffer types reject local selections and motions even with a source filetype", function()
  local bufnr = Runtime.buffer(t, { "before", "function f() end" })
  for _, buftype in ipairs({ "help", "prompt", "quickfix" }) do
    vim.api.nvim_set_option_value("buftype", buftype, { buf = bufnr })
    t.assert_nil(Textobject.find("a", "f"), buftype .. " selection")
    Textobject.move({ "function.outer" }, "textobjects", 1, false, 1)
    t.assert_eq(1, vim.api.nvim_win_get_cursor(0)[1], buftype .. " motion")
  end
  vim.api.nvim_set_option_value("buftype", "", { buf = bufnr })
  vim.api.nvim_open_term(bufnr, {})
  t.assert_eq("terminal", vim.api.nvim_get_option_value("buftype", { buf = bufnr }))
  t.assert_false(Find.is_enabled(bufnr), "terminal buffer")
end)

t:test("unloaded and deleted buffers are ineligible without accessing their options", function()
  local bufnr = Runtime.buffer(t, { "text" })
  vim.api.nvim_buf_set_name(bufnr, "test://textobject/eligibility")
  vim.api.nvim_buf_delete(bufnr, { unload = true, force = true })
  t.assert_true(vim.api.nvim_buf_is_valid(bufnr), "unloaded buffer remains valid")
  t.assert_false(Find.is_enabled(bufnr), "unloaded buffer")
  vim.api.nvim_buf_delete(bufnr, { force = true })
  t.assert_false(Find.is_enabled(bufnr), "deleted buffer")
end)

t:run()
