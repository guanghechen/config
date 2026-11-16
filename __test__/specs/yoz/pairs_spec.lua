local harness = require("__test__.support.harness")
local bootstrap = require("__test__.support.bootstrap")
local fs = require("__test__.support.fs")
local t = harness.new()
local native = bootstrap.with_native(t)

local FIXTURE = "__test__/fixtures/yoz/pairs/blink.json"
---@type string[][]
local DELIMITERS = { { "(", ")" }, { "[", "]" }, { "{", "}" } }

--- The fields of a token joined by `|`, an absent one as `nil`.
---@param ...                           any
---@return string
local function key(...)
  local fields = {} ---@type string[]
  for index = 1, select("#", ...) do
    fields[index] = tostring((select(index, ...)))
  end
  return table.concat(fields, "|")
end

---@param open_row                      integer|nil
---@param open_col                      integer|nil
---@param _                             integer|nil
---@param close_row                     integer|nil
---@param close_col                     integer|nil
---@return string
local function pair_key(open_row, open_col, _, close_row, close_col)
  return open_row and string.format("%d,%d,%d,%d", open_row, open_col, close_row, close_col) or "-"
end

---@param row                           integer|nil
---@param col                           integer|nil
---@return string
local function position_key(row, col)
  return row and string.format("%d,%d", row, col) or "-"
end

---@param language                      string
---@param lines                         string[]
---@param tab_width                     ?integer
---@return yoz.pairs.Document
local function parse(language, lines, tab_width)
  local document = native.pairs.new(language, tab_width or 4)
  document:edit(0, 0, lines)
  return document
end

t:test("filetypes map to blink.pairs' languages", function()
  t.assert_eq("javascript", native.pairs.language("typescriptreact"))
  t.assert_eq("latex", native.pairs.language("tex"))
  t.assert_eq("lua", native.pairs.language("lua"))
  t.assert_nil(native.pairs.language("sh"))
  t.assert_error(function()
    native.pairs.new("sh", 4)
  end, "unknown pairs language")
end)

t:test("tokens, heights and pair queries reproduce blink.pairs", function()
  local fixture = vim.json.decode((fs.read(FIXTURE)))
  t.assert_true(#fixture.cases > 100)
  for _, case in ipairs(fixture.cases) do
    local document = parse(case.language, case.lines, case.tab_width)
    for row = 0, #case.lines - 1 do
      local actual = {} ---@type string[]
      for _, token in ipairs(document:tokens(row)) do
        actual[#actual + 1] = key(token.col, token.open, token.close, token.span, token.height)
      end
      table.sort(actual)
      t.assert_same(case.tokens[row + 1], actual, string.format("%s: tokens of row %d", case.name, row))
    end
    for row = 0, #case.lines - 1, case.query_every do
      for col = 0, #case.lines[row + 1] + 1 do
        local values = { pair_key(document:match_pair(row, col)), pair_key(document:surrounding_pair(row, col)) }
        for _, delimiter in ipairs(DELIMITERS) do
          values[#values + 1] = position_key(document:unmatched_closing_after(delimiter[1], delimiter[2], row, col))
          values[#values + 1] = position_key(document:unmatched_opening_before(delimiter[1], delimiter[2], row, col))
        end
        local actual = table.concat(values, " ")
        local expected = case.queries[row .. ":" .. col] or actual:gsub("[^ ]+", "-")
        t.assert_eq(expected, actual, string.format("%s: queries at %d:%d", case.name, row, col))
      end
    end
  end
end)

t:test("an edit that changes the state entering later lines retokenizes them", function()
  local document = parse("c", { "int a;", "f(x);", "g(y);" })
  t.assert_eq(2, #document:tokens(1))
  document:edit(0, 1, { "/* int a;" })
  t.assert_same({}, document:tokens(2))
  document:edit(2, 3, { "g(y); */" })
  local last = document:tokens(2)
  t.assert_eq("*/", last[#last].close)
  t.assert_eq(0, last[#last].height)
end)

t:test("highlights pack the delimiters of a range with their heights and -1 when unmatched", function()
  local document = parse("lua", { "f(a[1], {", "})", ")" })
  t.assert_same(
    { 0, 1, 2, 0, 0, 3, 4, 1, 0, 5, 6, 1, 0, 8, 9, 1, 1, 0, 1, 1, 1, 1, 2, 0, 2, 0, 1, -1 },
    document:highlights(0, 0, 3, 0)
  )
  t.assert_same({ 1, 0, 1, 1, 1, 1, 2, 0 }, document:highlights(1, 0, 2, 0))
  -- A long line contributes only the columns of the range.
  t.assert_same({ 0, 3, 4, 1, 0, 5, 6, 1 }, document:highlights(0, 3, 0, 8))
  t.assert_same({ 0, 8, 9, 1, 1, 0, 1, 1 }, document:highlights(0, 6, 1, 1))
end)

t:test("inside names the string, comment or span around a position", function()
  local document = parse("lua", { 'f("a", x) -- c', "y = [[C:\\]] .. g(z)" })
  t.assert_eq("string", document:inside(0, 3))
  t.assert_nil(document:inside(0, 5))
  t.assert_eq("line_comment", document:inside(0, 12))
  t.assert_eq("block_string", document:inside(1, 6))
  t.assert_nil(document:inside(1, 17))
end)

t:test("a new document never reuses the revision of another", function()
  local first = parse("lua", { "f()" })
  local second = parse("lua", { "f()" })
  t.assert_true(second:revision() > first:revision())
  local revision = second:revision()
  second:edit(0, 1, { "g()" })
  t.assert_true(second:revision() > revision)
end)

t:run()
