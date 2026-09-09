local harness = require("__test__.support.harness")
local Runtime = require("__test__.fixtures.era.m.textobject.runtime")
local t = harness.new("era.m.textobject.editing")
local clipboard = { ["+"] = { "PLUS" }, ["*"] = { "STAR" } }
local previous_clipboard = vim.g.clipboard
t:defer(function()
  vim.g.clipboard = previous_clipboard
end)
vim.g.clipboard = {
  name = "textobject in-memory clipboard",
  copy = {
    ["+"] = function(lines)
      clipboard["+"] = lines
    end,
    ["*"] = function(lines)
      clipboard["*"] = lines
    end,
  },
  paste = {
    ["+"] = function()
      return { clipboard["+"], "v" }
    end,
    ["*"] = function()
      return { clipboard["*"], "v" }
    end,
  },
  cache_enabled = 0,
}
local Textobject, messages = Runtime.setup(t)
local Action = require("era.m.textobject.action")

t:test("operator mappings respect native words and textobject whitespace", function()
  Runtime.buffer(t, { "word (  body  )" })
  Runtime.feed("diw")
  t.assert_eq(" (  body  )", vim.api.nvim_get_current_line())
  vim.api.nvim_win_set_cursor(0, { 1, 5 })
  Runtime.feed("di(")
  t.assert_eq(" (    )", vim.api.nvim_get_current_line())
end)

t:test("delete supports nested counts and dot-repeat at a new position", function()
  Runtime.buffer(t, { "(first) (second)" })
  vim.api.nvim_win_set_cursor(0, { 1, 2 })
  Runtime.feed("di)")
  vim.api.nvim_win_set_cursor(0, { 1, 5 })
  Runtime.feed(".")
  t.assert_eq("() ()", vim.api.nvim_get_current_line())
  Runtime.feed("u")
  t.assert_eq("() (second)", vim.api.nvim_get_current_line())
  vim.api.nvim_buf_set_lines(0, 0, -1, true, { "(a (bb))" })
  vim.api.nvim_win_set_cursor(0, { 1, 4 })
  Runtime.feed("d2a)")
  t.assert_eq("", vim.api.nvim_get_current_line())
end)

t:test("empty inner change inserts inside brackets and undoes as one edit", function()
  Runtime.buffer(t, { "() ()" })
  Runtime.feed("ci)好<Esc>")
  t.assert_eq("(好) ()", vim.api.nvim_get_current_line())
  Runtime.feed("u")
  t.assert_eq("() ()", vim.api.nvim_get_current_line())
  Runtime.feed("<C-r>")
  vim.api.nvim_win_set_cursor(0, { 1, 7 })
  Runtime.feed(".")
  t.assert_eq("(好) (好)", vim.api.nvim_get_current_line())
end)

t:test("multiline inner changes remove newlines without eating delimiters", function()
  Runtime.buffer(t, { "(", "  old", ")" })
  vim.api.nvim_win_set_cursor(0, { 2, 2 })
  Runtime.feed("ci)new<Esc>")
  t.assert_eq(vim.inspect({ "(new)" }), vim.inspect(vim.api.nvim_buf_get_lines(0, 0, -1, true)))
end)

t:test("UTF-8 contents are selected completely with inclusive and exclusive selection", function()
  for _, selection in ipairs({ "inclusive", "exclusive" }) do
    Runtime.buffer(t, { "前(中文🙂)后" })
    vim.o.selection = selection
    vim.api.nvim_win_set_cursor(0, { 1, 4 })
    Runtime.feed("yi)")
    t.assert_eq("中文🙂", vim.fn.getreg('"'), selection .. " yank")
    Runtime.feed("di)")
    t.assert_eq("前()后", vim.api.nvim_get_current_line(), selection .. " deletion")
  end
end)

t:test("visual inner selections expand through nested objects", function()
  Runtime.buffer(t, { "(a (bb))" })
  vim.api.nvim_win_set_cursor(0, { 1, 4 })
  Runtime.feed("vi)")
  t.assert_eq("bb", Runtime.text(Action.visual_range()))
  Runtime.feed("i)")
  t.assert_eq("a (bb)", Runtime.text(Action.visual_range()))
end)

t:test("forced linewise and blockwise operators retain their selection type", function()
  Runtime.buffer(t, { "aa (one", "bb two) cc", "last" })
  vim.api.nvim_win_set_cursor(0, { 1, 5 })
  Runtime.feed("dVa)")
  t.assert_eq(vim.inspect({ "last" }), vim.inspect(vim.api.nvim_buf_get_lines(0, 0, -1, true)))
  Runtime.buffer(t, { "aa (12", "bb 34) zz" })
  vim.api.nvim_win_set_cursor(0, { 1, 4 })
  Runtime.feed("d<C-v>i)")
  t.assert_eq(vim.inspect({ "aa (2", "bb 3) zz" }), vim.inspect(vim.api.nvim_buf_get_lines(0, 0, -1, true)))
end)

t:test("failed and cancelled operators leave text untouched", function()
  Runtime.buffer(t, { "plain text" }, "no_textobject_parser")
  Runtime.feed("di)")
  Runtime.feed("daf")
  Runtime.feed("di<Esc>")
  t.assert_eq("plain text", vim.api.nvim_get_current_line())
  t.assert_eq("n", vim.fn.mode())
  t.assert_true(#messages >= 2)
end)

t:test("entire-buffer and splitline objects use their documented whitespace boundaries", function()
  Runtime.buffer(t, { "", "alpha", "beta", "" })
  t.assert_eq("alpha\nbeta", Runtime.text(assert(Textobject.find("i", "g"))))
  t.assert_eq("\nalpha\nbeta\n", Runtime.text(assert(Textobject.find("a", "g"))))
  Runtime.buffer(t, { "------", "", "alpha", "", "------" })
  vim.api.nvim_win_set_cursor(0, { 3, 1 })
  Runtime.feed("yis")
  t.assert_eq("alpha", vim.fn.getreg('"'))
  Runtime.feed("yas")
  t.assert_eq("\nalpha\n", vim.fn.getreg('"'))
end)

t:test("hunk deletion is linewise and keeps both neighboring lines", function()
  local bufnr = Runtime.buffer(t, { "first", "changed", "also changed", "last" })
  local hunk = era.m.git.hunk
  hunk.set(bufnr, { { added = { start = 2, count = 2 }, vend = 3 } })
  t:defer(function()
    hunk.remove(bufnr)
  end)
  vim.api.nvim_win_set_cursor(0, { 2, 3 })
  Runtime.feed("dah")
  t.assert_eq(vim.inspect({ "first", "last" }), vim.inspect(vim.api.nvim_buf_get_lines(0, 0, -1, true)))
end)

t:test("numeric objects and edge motions retain complete signed numbers", function()
  Runtime.buffer(t, { "value = -12.5" })
  vim.api.nvim_win_set_cursor(0, { 1, 10 })
  Runtime.feed("yiN")
  t.assert_eq("-12.5", vim.fn.getreg('"'))
  Runtime.feed("g[n")
  t.assert_eq(vim.inspect({ 1, 8 }), vim.inspect(vim.api.nvim_win_get_cursor(0)))
end)

t:test("hunks include empty final lines without inserting a placeholder", function()
  local bufnr = Runtime.buffer(t, { "first", "changed", "" })
  local hunk = era.m.git.hunk
  hunk.set(bufnr, { { added = { start = 2, count = 2 }, vend = 3 } })
  t:defer(function()
    hunk.remove(bufnr)
  end)
  vim.api.nvim_win_set_cursor(0, { 2, 2 })
  Runtime.feed("dah")
  t.assert_eq("first", table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, true), "\n"))
  Runtime.feed("u")
  t.assert_eq("first\nchanged\n", table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, true), "\n"))
end)

t:test("prompted delimiter changes repeat without asking again", function()
  Runtime.buffer(t, { "/* one */ /* two */" })
  vim.api.nvim_win_set_cursor(0, { 1, 4 })
  Runtime.feed("ci?/*<CR>*/<CR>x<Esc>")
  t.assert_eq("/*x*/ /* two */", vim.api.nvim_get_current_line())
  vim.api.nvim_win_set_cursor(0, { 1, 9 })
  Runtime.feed(".")
  t.assert_eq("/*x*/ /*x*/", vim.api.nvim_get_current_line())
end)

t:test("UI buffers preserve native objects and reject recorded textobject edits", function()
  local bufnr = Runtime.buffer(t, { "(  first  ) (  second  )" })
  vim.api.nvim_win_set_cursor(0, { 1, 5 })
  Runtime.feed("di(")
  t.assert_eq("(    ) (  second  )", vim.api.nvim_get_current_line())
  vim.api.nvim_set_option_value("filetype", stl.filetype.BOARD, { buf = bufnr })
  vim.api.nvim_win_set_cursor(0, { 1, 11 })
  Runtime.feed(".")
  t.assert_eq("(    ) (  second  )", vim.api.nvim_get_current_line())
  Runtime.feed("yi(")
  t.assert_eq("  second  ", vim.fn.getreg('"'))
  t.assert_nil(Textobject.find("i", ")"))
  local cursor = vim.api.nvim_win_get_cursor(0)
  Runtime.feed("g[f")
  t.assert_eq(vim.inspect(cursor), vim.inspect(vim.api.nvim_win_get_cursor(0)))
  vim.api.nvim_set_option_value("filetype", "lua", { buf = bufnr })
  Runtime.feed("yi(")
  t.assert_eq("second", vim.fn.getreg('"'))
end)

t:test("unrelated quote state does not cross ordinary string lines", function()
  Runtime.buffer(t, { '-- unmatched " here', 'f("hello")', "do_work()", '-- close "' })
  vim.api.nvim_win_set_cursor(0, { 2, 4 })
  Runtime.feed('di"')
  t.assert_eq(
    '-- unmatched " here\nf("")\ndo_work()\n-- close "',
    table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, true), "\n")
  )
  Runtime.buffer(t, { "-- don't do this", "f(a, b)" })
  vim.api.nvim_win_set_cursor(0, { 2, 2 })
  Runtime.feed("dia")
  t.assert_eq("f(, b)", vim.api.nvim_get_current_line())
end)

t:test("explicit function modes preserve adjacent statements and repeat", function()
  local line = "before(); function f() return 1 end; after()"
  Runtime.buffer(t, { line, line })
  vim.api.nvim_win_set_cursor(0, { 1, 25 })
  Runtime.feed("dvaf")
  t.assert_eq("before(); ; after()", vim.api.nvim_get_current_line())
  vim.api.nvim_win_set_cursor(0, { 2, 25 })
  Runtime.feed(".")
  t.assert_eq("before(); ; after()", vim.api.nvim_get_current_line())
  Runtime.buffer(t, { line })
  vim.api.nvim_win_set_cursor(0, { 1, 25 })
  Runtime.feed("vafy")
  t.assert_eq("function f() return 1 end", vim.fn.getreg('"'))
  Runtime.feed("yaf")
  t.assert_eq(line .. "\n", vim.fn.getreg('"'), "unforced operator remains linewise")
end)

t:test("hunk edge repetition uses a legal UTF-8 cursor position", function()
  local bufnr = Runtime.buffer(t, { "before", "好🙂", "middle", "second", "" })
  local hunk = era.m.git.hunk
  hunk.set(bufnr, {
    { added = { start = 2, count = 1 }, vend = 2 },
    { added = { start = 4, count = 1 }, vend = 4 },
    { added = { start = 5, count = 1 }, vend = 5 },
  })
  local virtualedit = vim.o.virtualedit
  t:defer(function()
    hunk.remove(bufnr)
    vim.o.virtualedit = virtualedit
  end)
  vim.o.virtualedit = "block"
  vim.api.nvim_win_set_cursor(0, { 2, 0 })
  Runtime.feed("g]h")
  t.assert_eq(vim.inspect({ 2, 3 }), vim.inspect(vim.api.nvim_win_get_cursor(0)))
  Runtime.feed("g]h")
  t.assert_eq(vim.inspect({ 4, 5 }), vim.inspect(vim.api.nvim_win_get_cursor(0)))
  Runtime.feed("g]h")
  t.assert_eq(vim.inspect({ 5, 0 }), vim.inspect(vim.api.nvim_win_get_cursor(0)))
end)

t:test("linewise hunk selection advances and handles the final empty line", function()
  local bufnr = Runtime.buffer(t, { "before", "first", "middle", "second", "" })
  local hunk = era.m.git.hunk
  hunk.set(bufnr, {
    { added = { start = 2, count = 1 }, vend = 2 },
    { added = { start = 4, count = 2 }, vend = 5 },
  })
  t:defer(function()
    hunk.remove(bufnr)
  end)
  vim.api.nvim_win_set_cursor(0, { 2, 0 })
  Runtime.feed("vahah")
  t.assert_eq("second\n\n", Runtime.text(Action.visual_range()))
  Runtime.feed("ah")
  t.assert_eq("n", vim.fn.mode(), "no further hunk cancels selection without an EOF error")
end)

t:test("linewise function selection stays in its owner at the closing keyword", function()
  local lines = { "function first()", "  return 1", "end", "function second()", "  return 2", "end" }
  Runtime.buffer(t, lines)
  vim.api.nvim_win_set_cursor(0, { 3, 1 })
  Runtime.feed("Vify")
  t.assert_eq("  return 1\n", vim.fn.getreg('"'))
  vim.api.nvim_win_set_cursor(0, { 3, 1 })
  Runtime.feed("Vifd")
  t.assert_eq(
    "function first()\nend\nfunction second()\n  return 2\nend",
    table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, true), "\n")
  )
  Runtime.buffer(t, lines)
  vim.api.nvim_win_set_cursor(0, { 3, 1 })
  Runtime.feed("Vafd")
  t.assert_eq("function second()\n  return 2\nend", table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, true), "\n"))
end)

t:test("a paired backtick on the reference line wins over unrelated multiline pairs", function()
  Runtime.buffer(t, { "// unmatched ` here", "f(`hello`)", "do_work()", "// close `" })
  vim.api.nvim_win_set_cursor(0, { 2, 4 })
  Runtime.feed("di`")
  t.assert_eq(
    "// unmatched ` here\nf(``)\ndo_work()\n// close `",
    table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, true), "\n")
  )
  Runtime.buffer(t, { "f(`first", "second`)" })
  vim.api.nvim_win_set_cursor(0, { 1, 4 })
  Runtime.feed("yi`")
  t.assert_eq("first\nsecond", vim.fn.getreg('"'))
end)

t:test("empty changes preserve registers before insertion and on dot-repeat", function()
  local eventignore = vim.o.eventignore
  t:defer(function()
    vim.o.eventignore = eventignore
  end)
  for _, ignored in ipairs({ "", "all", "TextYankPost" }) do
    Runtime.buffer(t, { "() ()" })
    vim.o.eventignore = ignored
    vim.fn.setreg("0", "KEEP")
    vim.fn.setreg("-", "SMALL")
    vim.fn.setreg('"', { points_to = "0" })
    Runtime.feed('ci)<C-r>"<Esc>')
    t.assert_eq("(KEEP) ()", vim.api.nvim_get_current_line())
    t.assert_eq("KEEP", vim.fn.getreg('"'))
    t.assert_eq("0", vim.fn.getreginfo('"').points_to)
    t.assert_eq("SMALL", vim.fn.getreg("-"))
    vim.api.nvim_win_set_cursor(0, { 1, 7 })
    Runtime.feed(".")
    t.assert_eq("(KEEP) (KEEP)", vim.api.nvim_get_current_line())
    t.assert_eq("KEEP", vim.fn.getreg('"'))
    t.assert_eq("SMALL", vim.fn.getreg("-"))
    Runtime.feed("u")
    t.assert_eq("(KEEP) ()", vim.api.nvim_get_current_line())
  end
end)

t:test("empty deletes preserve named, append, numbered and unnamed registers", function()
  for _, prefix in ipairs({ "", '"a', '"A', '"_', '"0', '"1' }) do
    Runtime.buffer(t, { "()" })
    for index = 0, 9 do
      vim.fn.setreg(tostring(index), "number " .. index)
    end
    vim.fn.setreg("a", "NAMED")
    vim.fn.setreg("-", "SMALL")
    vim.fn.setreg('"', { points_to = "0" })
    Runtime.feed(prefix .. "di)")
    t.assert_eq("()", vim.api.nvim_get_current_line())
    t.assert_eq("NAMED", vim.fn.getreg("a"), prefix)
    t.assert_eq("SMALL", vim.fn.getreg("-"), prefix)
    t.assert_eq("number 0", vim.fn.getreg('"'), prefix)
    for index = 0, 9 do
      t.assert_eq("number " .. index, vim.fn.getreg(tostring(index)), prefix .. " register " .. index)
    end
  end
  Runtime.buffer(t, { "(body)" })
  Runtime.feed("di)")
  t.assert_eq("body", vim.fn.getreg('"'), "nonempty deletion still updates registers")
end)

t:test("empty changes preserve implicitly routed clipboard registers", function()
  clipboard["+"], clipboard["*"] = { "PLUS" }, { "STAR" }
  local option = vim.o.clipboard
  t:defer(function()
    vim.o.clipboard = option
  end)
  for _, flags in ipairs({ "unnamedplus", "unnamed", "unnamedplus,unnamed" }) do
    vim.o.clipboard = flags
    Runtime.buffer(t, { "()" })
    Runtime.feed("ci)<C-r>+<Esc>")
    t.assert_eq("(PLUS)", vim.api.nvim_get_current_line(), flags)
    t.assert_eq("PLUS", table.concat(clipboard["+"], "\n"), flags)
    t.assert_eq("STAR", table.concat(clipboard["*"], "\n"), flags)
  end
end)

t:test("argument containers ignore unrelated preceding backticks", function()
  Runtime.buffer(t, { "-- unmatched `", "f(a, b)", "-- close `", "g(c, d)" })
  vim.api.nvim_win_set_cursor(0, { 2, 2 })
  Runtime.feed("dia")
  t.assert_eq(
    "-- unmatched `\nf(, b)\n-- close `\ng(c, d)",
    table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, true), "\n")
  )

  Runtime.buffer(t, { "-- unmatched `", "f(", "  `first,", "nested(a, b)", "last`,", "  second", ")", "g(c, d)" })
  vim.api.nvim_win_set_cursor(0, { 4, 10 })
  Runtime.feed("yia")
  t.assert_eq("`first,\nnested(a, b)\nlast`", vim.fn.getreg('"'), "multiline string remains one argument")
  Runtime.feed("dia")
  t.assert_eq(
    "-- unmatched `\nf(\n  ,\n  second\n)\ng(c, d)",
    table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, true), "\n")
  )
end)

t:test("an operator error cannot restore its register snapshot during a later selection", function()
  local group = vim.api.nvim_create_augroup("textobject_register_failure", { clear = true })
  local errmsg = vim.v.errmsg
  t:defer(function()
    vim.api.nvim_del_augroup_by_id(group)
    vim.v.errmsg = errmsg
  end)
  local failed = false
  vim.api.nvim_create_autocmd("TextYankPost", {
    group = group,
    once = true,
    callback = function()
      failed = true
      error("intentional textobject cleanup regression")
    end,
  })
  Runtime.buffer(t, { "()" })
  vim.fn.setreg("0", "OLD")
  vim.fn.setreg('"', { points_to = "0" })
  -- The native error discards the queued finish_select command.
  Runtime.feed("ci)X<Esc>")
  t.assert_true(failed)

  Runtime.buffer(t, { "NEW (body)" })
  vim.cmd("normal! yiw")
  t.assert_eq("NEW", vim.fn.getreg('"'))
  vim.api.nvim_win_set_cursor(0, { 1, 6 })
  Runtime.feed("di)")
  t.assert_eq("NEW ()", vim.api.nvim_get_current_line())
  t.assert_eq("body", vim.fn.getreg('"'))
  t.assert_eq("NEW", vim.fn.getreg("0"))
end)

t:run()
