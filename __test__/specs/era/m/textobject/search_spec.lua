local harness = require("__test__.support.harness")
local Pattern = require("era.m.textobject.pattern")
local Search = require("era.m.textobject.search")
local Source = require("era.m.textobject.source")
local t = harness.new("era.m.textobject.search")

---@param text                          string
---@param id                            string
---@param kind                          era.m.textobject.Kind
---@param column                        integer
---@param count                         ?integer
---@return string|nil
local function selected(text, id, kind, column, count)
  local span = Search.find(Pattern.collect(text, id), { from = column, to = column }, kind, count or 1, nil)
  return span and text:sub(span.from, span.to - 1) or nil
end

t:test("brackets preserve whitespace, aliases, nesting, and counts", function()
  t.assert_eq("foo", selected("(  foo  )", "(", "i", 5))
  t.assert_eq("  foo  ", selected("(  foo  )", ")", "i", 5))
  t.assert_eq("{bb}", selected("[a {bb}]", "b", "a", 5))
  t.assert_eq("[a {bb}]", selected("[a {bb}]", "b", "a", 5, 2))
  t.assert_nil(selected("[a {bb}]", "b", "a", 5, 3))
  t.assert_eq("", selected("()", ")", "i", 1))
end)

t:test("cover-or-next searches ahead and expands a selected inner range", function()
  t.assert_eq("(c)", selected("(a) bbb (c)", ")", "a", 6))
  local text = "(a (bb))"
  local range = Search.find(Pattern.collect(text, ")"), { from = 5, to = 7 }, "i", 1, nil)
  t.assert_eq("a (bb)", text:sub(range.from, range.to - 1))
end)

t:test("current-line candidates take priority over a multiline covering object", function()
  local text = "(\n  cursor (next)\n)"
  local range = Search.find(Pattern.collect(text, ")"), { from = 5, to = 5 }, "a", 1, { from = 3, to = 18 })
  t.assert_eq("(next)", text:sub(range.from, range.to - 1))
end)

t:test("quotes pair escaped delimiters and find following quote types", function()
  t.assert_eq('a\\"b', selected('"a\\"b"', '"', "i", 3))
  t.assert_eq("'next'", selected("\"first\" x 'next'", "q", "a", 9))
end)

t:test("arguments exclude nested and quoted commas and closing brackets", function()
  local text = 'f(a, g(b, c), "d,e)")'
  t.assert_eq("g(b, c)", selected(text, "a", "i", 6))
  t.assert_eq(", g(b, c)", selected(text, "a", "a", 6))
  t.assert_eq("b", selected(text, "a", "i", 8))
  t.assert_eq('"d,e)"', selected(text, "a", "i", 15))
  t.assert_eq("a,", selected(text, "a", "a", 3))
end)

t:test("function call variants preserve or omit the receiver", function()
  t.assert_eq("obj.method(x, y)", selected("obj.method(x, y)", "u", "a", 12))
  t.assert_eq("method(x, y)", selected("obj.method(x, y)", "U", "a", 12))
  t.assert_eq("x, y", selected("obj.method(x, y)", "u", "i", 12))
end)

t:test("digits, signed decimals, and subwords keep full boundaries", function()
  t.assert_eq("123", selected("item123", "d", "i", 7))
  t.assert_eq("-12.5", selected("value = -12.5", "N", "i", 11))
  t.assert_eq("Response", selected("getHTTPResponse_foo123", "e", "i", 9))
  t.assert_eq("foo123", selected("getHTTPResponse_foo123", "e", "i", 18))
  for column = 1, 5 do
    t.assert_eq("camel", selected("camelCase_snake_case", "e", "i", column))
    t.assert_eq("Case", selected("camelCase_snake_case", "e", "i", column, 2))
  end
end)

t:test("tags, arbitrary delimiters, and prompts return different inner and outer ranges", function()
  t.assert_eq("hello", selected('<my-tag class="x">hello</my-tag>', "t", "i", 20))
  t.assert_eq("bb__", selected("aa_bb__cc", "_", "a", 5))
  t.assert_eq("bb", selected("aa_bb__cc", "_", "i", 5))
  local text = "before /* comment */ after"
  local range = Search.find(Pattern.collect(text, "?", { "/*", "*/" }), { from = 12, to = 12 }, "i", 1, nil)
  t.assert_eq(" comment ", text:sub(range.from, range.to - 1))
end)

t:test("source conversions preserve UTF-8 bytes, newlines, and empty boundaries", function()
  local source = Source.new({ "中文", "", "(好)" }, 20)
  for offset = 1, #source.text + 1 do
    local row, col = Source.position(source, offset)
    t.assert_eq(offset, Source.offset(source, row, col), "offset round trip")
  end
  local range = { 20, 3, 22, 4 }
  t.assert_eq(vim.inspect(range), vim.inspect(Source.range(source, Source.span(source, range))))
  t.assert_eq(vim.inspect({ 21, 0, 21, 0 }), vim.inspect(Source.range(source, Source.span(source, { 21, 0, 21, 0 }))))
end)

t:test("quote boundaries retain escaped newlines and multiline backticks", function()
  t.assert_eq("a\\\nb", selected('"a\\\nb"', '"', "i", 2))
  t.assert_eq("a,\nb", selected("`a,\nb`", "`", "i", 2))
  t.assert_eq("`a,\nb`", selected("f(`a,\nb`, c)", "a", "i", 4))
end)

t:test("deep bracket nesting preserves every inner and outer range", function()
  local depth = 8000
  local text = string.rep("(", depth) .. "x" .. string.rep(")", depth)
  local candidates = Pattern.collect(text, "(")
  t.assert_eq(depth, #candidates)
  local range = assert(Search.find(candidates, { from = depth + 1, to = depth + 1 }, "i", 1))
  t.assert_eq("x", text:sub(range.from, range.to - 1))
  range = assert(Search.find(candidates, { from = 1, to = 1 }, "a", 1))
  t.assert_eq(text, text:sub(range.from, range.to - 1))
end)

t:run()
