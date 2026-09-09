local harness = require("__test__.support.harness")
local Runtime = require("__test__.fixtures.era.m.textobject.runtime")
local t = harness.new("era.m.textobject.treesitter")
local Textobject = Runtime.setup(t)
local Treesitter = require("era.m.textobject.treesitter")

t:test("local queries provide inner and outer functions without external plugins", function()
  Runtime.buffer(t, { "local function add(a, b)", "  return a + b", "end" })
  vim.api.nvim_win_set_cursor(0, { 2, 3 })
  t.assert_eq("return a + b", Runtime.text(assert(Textobject.find("i", "f"))))
  Runtime.feed("yaf")
  t.assert_eq("local function add(a, b)\n  return a + b\nend\n", vim.fn.getreg('"'))
  t.assert_nil(package.loaded["mini.ai"])
  t.assert_nil(package.loaded["nvim-treesitter-textobjects"])
  t.assert_nil(package.loaded["nvim-treesitter"])
end)

t:test("function deletion and repeat recompute ranges after edits", function()
  Runtime.buffer(t, { "function first()", "  return 1", "end", "function second()", "  return 2", "end", "after()" })
  Runtime.feed("daf")
  t.assert_eq("function second()", vim.api.nvim_buf_get_lines(0, 0, 1, true)[1])
  Runtime.feed(".")
  t.assert_eq("after()", vim.api.nvim_get_current_line())
  Runtime.feed("u")
  t.assert_eq("function second()", vim.api.nvim_buf_get_lines(0, 0, 1, true)[1])
end)

t:test("query captures honor offsets and span quantified nodes", function()
  local bufnr = Runtime.buffer(t, { "-- hello", "function f()", "  first()", "  second()", "end" })
  vim.treesitter.query.set(
    "lua",
    "textobjects",
    [[
    ((comment) @comment.inner (#offset! @comment.inner 0 3 0 0))
    (block (_) @body.inner (_) @body.inner)
  ]]
  )
  t:defer(function()
    vim.treesitter.query.set("lua", "textobjects", nil)
  end)
  local comments = Treesitter.ranges(bufnr, { "comment.inner" }, "textobjects", { 0, 4 })
  t.assert_eq("hello", Runtime.text(comments[1]))
  local bodies = Treesitter.ranges(bufnr, { "body.inner" }, "textobjects", { 2, 3 })
  t.assert_eq("first()\n  second()", Runtime.text(bodies[1]))
end)

t:test("injected Lua functions are resolved inside Markdown fences", function()
  Runtime.buffer(t, { "# Example", "", "```lua", "local function f()", "  return 1", "end", "```" }, "markdown")
  vim.api.nvim_win_set_cursor(0, { 5, 3 })
  t.assert_eq("return 1", Runtime.text(assert(Textobject.find("i", "f"))))
  t.assert_eq("local function f()\n  return 1\nend", Runtime.text(assert(Textobject.find("a", "f"))))
end)

t:test("Markdown headings and prose look ahead to sibling injected functions", function()
  Runtime.buffer(
    t,
    { "# Example", "", "Some text", "", "```lua", "function f()", "  return 1", "end", "```" },
    "markdown"
  )
  for _, cursor in ipairs({ { 1, 3 }, { 3, 2 } }) do
    vim.api.nvim_win_set_cursor(0, cursor)
    vim.fn.setreg('"', "not selected")
    Runtime.feed("yif")
    t.assert_eq("return 1", vim.fn.getreg('"'), "lookahead from row " .. cursor[1])
  end
end)

t:test("structural motions preserve direction, end positions, and counts", function()
  Runtime.buffer(t, { "-- before", "function a() end", "function b() end", "function c() end" })
  Runtime.feed("2]f")
  t.assert_eq(vim.inspect({ 3, 0 }), vim.inspect(vim.api.nvim_win_get_cursor(0)))
  Runtime.feed("[f")
  t.assert_eq(vim.inspect({ 2, 0 }), vim.inspect(vim.api.nvim_win_get_cursor(0)))
  Runtime.feed("]F")
  t.assert_eq(vim.inspect({ 2, 15 }), vim.inspect(vim.api.nvim_win_get_cursor(0)))
  Runtime.feed("g[f")
  t.assert_eq(vim.inspect({ 2, 0 }), vim.inspect(vim.api.nvim_win_get_cursor(0)))
end)

t:test("structural end operators include function, parameter, and class targets", function()
  Runtime.buffer(t, { "function f() end; after()" })
  Runtime.feed("y]F")
  t.assert_eq("function f() end", vim.fn.getreg('"'))
  Runtime.feed("d]F")
  t.assert_eq("; after()", vim.api.nvim_get_current_line())

  Runtime.buffer(t, { "f(first, second)" })
  vim.api.nvim_win_set_cursor(0, { 1, 2 })
  Runtime.feed("y]A")
  t.assert_eq("first", vim.fn.getreg('"'))
  Runtime.feed("d]A")
  t.assert_eq("f(, second)", vim.api.nvim_get_current_line())

  vim.treesitter.query.set("lua", "textobjects", "(function_declaration) @class.outer")
  t:defer(function()
    vim.treesitter.query.set("lua", "textobjects", nil)
  end)
  Runtime.buffer(t, { "function f() end; after()" })
  Runtime.feed("d]C")
  t.assert_eq("; after()", vim.api.nvim_get_current_line())
end)

t:test("structural operators preserve explicitly forced selection modes", function()
  local line = "before(); function f() end; after()"
  Runtime.buffer(t, { line, "keep()" })
  for _, mode in ipairs({ "v", "V", "<C-v>" }) do
    vim.api.nvim_win_set_cursor(0, { 1, 10 })
    Runtime.feed("y" .. mode .. "]F")
    t.assert_eq(mode == "V" and line .. "\n" or "function f() end", vim.fn.getreg('"'), mode)
    t.assert_eq(mode == "<C-v>" and "\22" or mode, vim.fn.getregtype('"'):sub(1, 1), mode .. " register type")
  end
end)

t:test("structural dot-repeat replaces the original count", function()
  local remaining = { "between()", "function g() end", "middle()", "function h() end", "after()" }
  Runtime.buffer(t, vim.list_extend({ "before()", "function f() end" }, remaining))
  Runtime.feed("dV]f")
  t.assert_eq(vim.inspect(remaining), vim.inspect(vim.api.nvim_buf_get_lines(0, 0, -1, true)))
  Runtime.feed("2.")
  t.assert_eq("after()", table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, true), "\n"))
  Runtime.feed("u")
  t.assert_eq(vim.inspect(remaining), vim.inspect(vim.api.nvim_buf_get_lines(0, 0, -1, true)))
end)

t:test("structural dot-repeat retains its count when no replacement is supplied", function()
  Runtime.buffer(t, {
    "before()",
    "function f() end",
    "between()",
    "function g() end",
    "middle()",
    "function h() end",
    "near_end()",
    "function i() end",
    "after()",
  })
  Runtime.feed("2dV]f")
  t.assert_eq("middle()", vim.api.nvim_get_current_line())
  Runtime.feed(".")
  t.assert_eq("after()", table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, true), "\n"))
end)

t:test("scope and fold queries remain separate from textobject queries", function()
  Runtime.buffer(t, { "-- before", "function f()", "  body()", "end" })
  vim.treesitter.query.set("lua", "locals", "(function_declaration) @local.scope")
  vim.treesitter.query.set("lua", "folds", "(function_declaration) @fold")
  t:defer(function()
    vim.treesitter.query.set("lua", "locals", nil)
    vim.treesitter.query.set("lua", "folds", nil)
  end)
  Runtime.feed("]s")
  t.assert_eq(vim.inspect({ 2, 0 }), vim.inspect(vim.api.nvim_win_get_cursor(0)))
  Runtime.feed("yiS")
  t.assert_eq("function f()\n  body()\nend", vim.fn.getreg('"'))
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  Runtime.feed("]z")
  t.assert_eq(vim.inspect({ 2, 0 }), vim.inspect(vim.api.nvim_win_get_cursor(0)))
end)

t:test("missing captures do not move or mutate the buffer", function()
  Runtime.buffer(t, { "local value = 1" })
  Runtime.feed("dac")
  t.assert_eq("local value = 1", vim.api.nvim_get_current_line())
  Runtime.feed("]c")
  t.assert_eq(vim.inspect({ 1, 0 }), vim.inspect(vim.api.nvim_win_get_cursor(0)))
end)

t:test("captures ending at the buffer boundary retain the final line", function()
  Runtime.buffer(t, { "paragraph at EOF" }, "markdown")
  t.assert_eq("paragraph at EOF", Runtime.text(assert(Textobject.find("a", "o"))))
end)

t:test("inner functions stay inside their owner when invoked on its closing keyword", function()
  Runtime.buffer(t, { "function first()", "  return 1", "end", "function second()", "  return 2", "end" })
  vim.api.nvim_win_set_cursor(0, { 3, 1 })
  Runtime.feed("yif")
  t.assert_eq("return 1", vim.fn.getreg('"'))
end)

t:test("linewise functions include blank lines without consuming the next indented function", function()
  Runtime.buffer(t, { "function first()", "end", "", "  function second()", "  end" })
  Runtime.feed("daf")
  t.assert_eq("  function second()\n  end", table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, true), "\n"))
end)

t:test("large sibling sets and nested functions retain the correct inner owner", function()
  local lines = {} ---@type string[]
  for index = 1, 1000 do
    vim.list_extend(lines, { "function f" .. index .. "()", "  return " .. index, "end" })
  end
  Runtime.buffer(t, lines)
  vim.api.nvim_win_set_cursor(0, { 1500, 1 })
  t.assert_eq("return 500", Runtime.text(assert(Textobject.find("i", "f"))))
  Runtime.buffer(t, { "function outer()", "  function inner()", "    return 1", "  end", "  return 2", "end" })
  vim.api.nvim_win_set_cursor(0, { 4, 3 })
  t.assert_eq("return 1", Runtime.text(assert(Textobject.find("i", "f"))))
  t.assert_eq(
    "function inner()\n    return 1\n  end\n  return 2",
    Runtime.text(assert(Textobject.find("i", "f", { count = 2 })))
  )
end)

t:test("bounded queries retain enclosing bodies and distant count targets", function()
  local lines = { "function first()", "  return 1" }
  for _ = 1, 1100 do
    lines[#lines + 1] = ""
  end
  lines[#lines + 1] = "end"
  local closing = #lines
  for _ = 1, 1100 do
    lines[#lines + 1] = ""
  end
  lines[#lines + 1] = "function second() return 2 end"
  Runtime.buffer(t, lines)
  vim.api.nvim_win_set_cursor(0, { closing, 1 })
  t.assert_eq("return 1", Runtime.text(assert(Textobject.find("i", "f"))))
  t.assert_eq("return 2", Runtime.text(assert(Textobject.find("i", "f", { count = 2 }))))
  vim.api.nvim_win_set_cursor(0, { closing + 1, 0 })
  t.assert_eq("return 2", Runtime.text(assert(Textobject.find("i", "f"))))
end)

t:test("explicit class selection overrides its blockwise default", function()
  Runtime.buffer(t, { "before(); function f() return 1 end; after()" })
  vim.treesitter.query.set("lua", "textobjects", "(function_declaration) @class.outer")
  t:defer(function()
    vim.treesitter.query.set("lua", "textobjects", nil)
  end)
  vim.api.nvim_win_set_cursor(0, { 1, 25 })
  Runtime.feed("vacy")
  t.assert_eq("function f() return 1 end", vim.fn.getreg('"'))
  t.assert_eq("v", vim.fn.getregtype('"'))
end)

t:test("bounded structural motions do not skip distant siblings for enclosing edges", function()
  local lines = { "function outer()" }
  for _ = 2, 1200 do
    lines[#lines + 1] = ""
  end
  lines[600] = "  function inner() return 1 end"
  lines[1100] = "end"
  lines[1200] = "function after() end"
  Runtime.buffer(t, lines)
  vim.api.nvim_win_set_cursor(0, { 2, 0 })
  Runtime.feed("]F")
  t.assert_eq(600, vim.api.nvim_win_get_cursor(0)[1])
  vim.api.nvim_win_set_cursor(0, { 2, 0 })
  Runtime.feed("]f")
  t.assert_eq(600, vim.api.nvim_win_get_cursor(0)[1])
  vim.api.nvim_win_set_cursor(0, { 1200, 0 })
  Runtime.feed("[f")
  t.assert_eq(600, vim.api.nvim_win_get_cursor(0)[1])
end)

t:test("shared function envelopes retain the narrower inner capture", function()
  Runtime.buffer(t, { "function f()", "  work()", "  return 1", "end" })
  vim.treesitter.query.set(
    "lua",
    "textobjects",
    [[
    (function_declaration body: (block) @function.inner) @function.outer
    (function_declaration body: (block (return_statement) @function.inner))
  ]]
  )
  t:defer(function()
    vim.treesitter.query.set("lua", "textobjects", nil)
  end)
  vim.api.nvim_win_set_cursor(0, { 3, 4 })
  Runtime.feed("yif")
  t.assert_eq("return 1", vim.fn.getreg('"'))
  Runtime.feed("dif")
  t.assert_eq("function f()\n  work()\n  \nend", table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, true), "\n"))
end)

t:test("a failed bounded lookup performs only one full query", function()
  local lines = { "function first() return 1 end" }
  for _ = 1, 1000 do
    lines[#lines + 1] = ""
  end
  Runtime.buffer(t, lines)
  vim.api.nvim_win_set_cursor(0, { #lines, 0 })
  local query = assert(vim.treesitter.query.get("lua", "textobjects"))
  local iterate = query.iter_matches
  local full_queries = 0
  t:patch_table(query, "iter_matches", function(self, node, bufnr, first, last, opts)
    if first == 0 and last == -1 then
      full_queries = full_queries + 1
    end
    return iterate(self, node, bufnr, first, last, opts)
  end)
  Runtime.feed("]f")
  t.assert_eq(1, full_queries)
  t.assert_eq(#lines, vim.api.nvim_win_get_cursor(0)[1])
  full_queries = 0
  t.assert_nil(Textobject.find("i", "f"))
  t.assert_eq(1, full_queries)
end)

t:run()
