---@diagnostic disable: undefined-global

local harness = require("__test__.harness")

local t = harness.new("era.m.cmp.label")

---@param on_parser                    fun(label: string, lang: string): table
---@return era.m.cmp.label
local function setup(on_parser)
  t:patch_table(vim.treesitter.language, "get_lang", function(filetype)
    return filetype .. "_lang"
  end)
  t:patch_table(vim.treesitter, "get_string_parser", on_parser)
  return assert(loadfile("lua/era/m/cmp/label.lua"))()
end

---@param source                        string
local function parser(source)
  local nodes = {}
  for index, text in ipairs(vim.split(source, "\n", { plain = true })) do
    local row = index - 1
    nodes[#nodes + 1] = {
      capture = 1,
      node = {
        range = function()
          return row, 1, row, #text
        end,
      },
    }
  end
  nodes[#nodes + 1] = {
    capture = 2,
    node = {
      range = function()
        return 0, 0, 0, 1
      end,
    },
  }
  local query = { captures = { "function", "spell" } }
  function query:iter_captures()
    local index = 0
    return function()
      index = index + 1
      local value = nodes[index]
      if value ~= nil then
        return value.capture, value.node
      end
    end
  end
  t:patch_table(vim.treesitter.query, "get", function()
    return query
  end)
  return {
    parse = function() end,
    for_each_tree = function(_, callback)
      callback({
        root = function()
          return {}
        end,
      }, {
        lang = function()
          return "lua"
        end,
      })
    end,
  }
end

t:test("display labels normalize all newline forms", function()
  local label = setup(function(source)
    return parser(source)
  end)

  t.assert_eq("a↲b↲c↲d", label.display("a\r\nb\rc\nd"), "single-line display")
end)

t:test("semantic projection is cached per filetype and match ranges have higher priority", function()
  local parser_calls = 0
  local label = setup(function(source)
    parser_calls = parser_calls + 1
    return parser(source)
  end)
  local items = { { label = "print", _era_cmp_origin = {} }, { label = "value", _era_cmp_origin = {} } }

  local highlights, resolve = label.project("lua", items, { { 0, 1, 2, 4 }, { 0, 1 } })
  local semantic = assert(resolve)({ 1, 2 })
  assert(resolve)({ 1, 2 })
  local _, resolve_python = label.project("python", items, { {}, {} })
  assert(resolve_python)({ 1, 2 })

  t.assert_eq(4, parser_calls, "filetype-scoped cache")
  t.assert_true(vim.deep_equal({ 1, 5, "@function.lua_lang", 100 }, semantic[1][1]), "semantic capture")
  t.assert_true(vim.deep_equal({ 0, 1, "PmenuMatch", 150 }, highlights[1][1]), "first match")
  t.assert_true(vim.deep_equal({ 2, 4, "PmenuMatch", 150 }, highlights[1][2]), "second match")
end)

t:test("deprecated items skip semantic parsing and retain fuzzy matches", function()
  local parser_calls = 0
  local label = setup(function(source)
    parser_calls = parser_calls + 1
    return parser(source)
  end)
  local highlights, resolve = label.project(
    "lua",
    { { label = "old", deprecated = true, _era_cmp_origin = {} } },
    { { 0, 1 } }
  )

  t.assert_eq(0, parser_calls, "parser calls")
  t.assert_nil(resolve, "semantic resolver")
  t.assert_true(vim.deep_equal({ { 0, 1, "PmenuMatch", 150 } }, highlights[1]), "match projection")
end)

t:test("parser failures degrade to fuzzy match highlighting and are cached", function()
  local parser_calls = 0
  local label = setup(function()
    parser_calls = parser_calls + 1
    error("missing parser")
  end)
  local item = { label = "value", _era_cmp_origin = {} }

  local highlights, resolve = label.project("lua", { item }, { { 0, 1 } })
  local semantic = assert(resolve)({ 1 })
  assert(resolve)({ 1 })

  t.assert_eq(1, parser_calls, "failed result cache")
  t.assert_true(vim.deep_equal({}, semantic[1]), "semantic fallback")
  t.assert_true(vim.deep_equal({ { 0, 1, "PmenuMatch", 150 } }, highlights[1]), "match projection")
end)

t:run()
