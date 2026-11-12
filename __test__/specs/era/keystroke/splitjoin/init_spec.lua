local bootstrap = require("__test__.support.bootstrap")
local harness = require("__test__.support.harness")
local textobject = require("__test__.support.textobject")

local t = harness.new()

bootstrap.with_runtime(t, {
  stl = {
    nvim = {
      fn = require("stl.nvim.fn"),
    },
  },
  era = {
    keystroke = require("era.keystroke"),
  },
})

local Splitjoin = era.keystroke.splitjoin
Splitjoin.setup()

-- Shows `lines` indented by two spaces in the current window.
---@param lines                         string[]
---@return integer
local function buffer(lines)
  local bufnr = t:buffer(lines, { current = true }) ---@type integer
  vim.api.nvim_set_option_value("expandtab", true, { buf = bufnr })
  vim.api.nvim_set_option_value("shiftwidth", 2, { buf = bufnr })
  vim.api.nvim_set_option_value("tabstop", 2, { buf = bufnr })
  return bufnr
end

---@param expected                      string[]
---@param bufnr                         integer
---@param message                       string
---@return nil
local function assert_lines(expected, bufnr, message)
  local actual = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false) ---@type string[]
  t.assert_same(expected, actual, message)
end

t:test("setup keeps action implementation lazy", function()
  t.assert_nil(package.loaded["era.keystroke.splitjoin.action"], "action loaded during setup")
end)

t:test("split resolves the smallest bracket region", function()
  local bufnr = buffer({ [[call(alpha, nested(one, two), "x,y", omega,)]] })
  vim.api.nvim_win_set_cursor(0, { 1, 20 })
  Splitjoin.split()
  assert_lines({ "call(alpha, nested(", "  one,", "  two", [[), "x,y", omega,)]] }, bufnr, "smallest region")
end)

t:test("split finds the call after a long malformed bracket prefix", function()
  local count = 20000 ---@type integer
  local prefix = string.rep("[", count) .. string.rep(")", count) .. " call" ---@type string
  local bufnr = buffer({ prefix .. "(alpha, beta)" })
  vim.api.nvim_win_set_cursor(0, { 1, #prefix + 2 })
  Splitjoin.split()
  assert_lines({ prefix .. "(", "  alpha,", "  beta", ")" }, bufnr, "region after malformed prefix")
end)

t:test("normal mappings split and join arguments", function()
  local bufnr = buffer({ "local value = call(alpha, beta)" })
  vim.api.nvim_win_set_cursor(0, { 1, 20 })
  textobject.feed("gS")
  assert_lines({ "local value = call(", "  alpha,", "  beta", ")" }, bufnr, "split")

  textobject.feed("gJ")
  assert_lines({ "local value = call(alpha, beta)" }, bufnr, "join")
end)

t:test("split is one undo step", function()
  local bufnr = buffer({ "call(alpha, beta)" })
  vim.api.nvim_win_set_cursor(0, { 1, 6 })
  textobject.feed("gS")
  textobject.feed("u")
  assert_lines({ "call(alpha, beta)" }, bufnr, "undo")
end)

t:test("join is one undo step", function()
  local original = { "call(", "  alpha,", "  beta", ")" } ---@type string[]
  local bufnr = buffer(original)
  vim.api.nvim_win_set_cursor(0, { 2, 3 })
  textobject.feed("gJ")
  textobject.feed("u")
  assert_lines(original, bufnr, "undo")
end)

t:test("split preserves byte positions in the later part of a buffer", function()
  local target = "local 文本 = call(alpha, beta)" ---@type string
  local bufnr = buffer({ "local preface = true", target })
  local alpha = assert(target:find("alpha", 1, true)) ---@type integer
  vim.api.nvim_win_set_cursor(0, { 2, alpha - 1 })
  textobject.feed("gS")
  assert_lines({ "local preface = true", "local 文本 = call(", "  alpha,", "  beta", ")" }, bufnr, "offset")
end)

t:test("split ignores nested and quoted separators and preserves a trailing comma", function()
  local bufnr = buffer({ [[call(alpha, nested(one, two), "x,y", { key = "a,b" }, omega,)]] })
  vim.api.nvim_win_set_cursor(0, { 1, 6 })
  textobject.feed("gS")
  assert_lines({
    "call(",
    "  alpha,",
    "  nested(one, two),",
    '  "x,y",',
    '  { key = "a,b" },',
    "  omega,",
    ")",
  }, bufnr, "nested split")
end)

t:test("split ignores quoted closing brackets and escaped quotes", function()
  local bufnr = buffer({ [[call(alpha, ")", "a\",b", beta)]] })
  vim.api.nvim_win_set_cursor(0, { 1, 6 })
  textobject.feed("gS")
  assert_lines({ "call(", "  alpha,", '  ")",', [[  "a\",b",]], "  beta", ")" }, bufnr, "quoted split")
end)

t:test("split and join preserve line comment leaders", function()
  local bufnr = buffer({ "  -- call(alpha, beta)" })
  vim.api.nvim_set_option_value("commentstring", "-- %s", { buf = bufnr })
  vim.api.nvim_set_option_value("comments", "b:--", { buf = bufnr })
  vim.api.nvim_win_set_cursor(0, { 1, 12 })

  textobject.feed("gS")
  assert_lines({ "  -- call(", "  --   alpha,", "  --   beta", "  -- )" }, bufnr, "comment split")

  textobject.feed("gJ")
  assert_lines({ "  -- call(alpha, beta)" }, bufnr, "comment join")
end)

t:test("visual mapping limits transformation to the selected region", function()
  local bufnr = buffer({ "first(a, b) second(c, d)" })
  vim.api.nvim_win_set_cursor(0, { 1, 18 })
  vim.cmd("normal! v5l")
  textobject.feed("gS")
  assert_lines({ "first(a, b) second(", "  c,", "  d", ")" }, bufnr, "selected region")
end)

t:test("split normalizes an already multiline region", function()
  local bufnr = buffer({ "call(", "  alpha,", "  beta", ")" })
  vim.api.nvim_win_set_cursor(0, { 2, 3 })
  textobject.feed("gS")
  assert_lines({ "call(", "  alpha,", "  beta", ")" }, bufnr, "normalized split")
end)

t:test("normal operator supports dot repeat", function()
  local bufnr = buffer({ "call(a, b) call(c, d)" })
  vim.api.nvim_win_set_cursor(0, { 1, 6 })
  textobject.feed("gS")
  vim.api.nvim_win_set_cursor(0, { 4, 8 })
  textobject.feed(".")
  assert_lines({ "call(", "  a,", "  b", ") call(", "  c,", "  d", ")" }, bufnr, "dot repeat")
end)

t:run()
