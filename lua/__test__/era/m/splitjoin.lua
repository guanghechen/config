---@diagnostic disable: undefined-global
--- Run with: nvim -l lua/__test__/era/m/splitjoin.lua

local bootstrap = require("__test__.bootstrap")
local harness = require("__test__.harness")

local t = harness.new("era.m.splitjoin")

bootstrap.with_runtime(t, {
  stl = {
    nvim = {
      fn = require("stl.nvim.fn"),
    },
  },
  era = {
    m = {},
  },
})

local Splitjoin = require("era.m.splitjoin")
era.m.splitjoin = Splitjoin
Splitjoin.dressing()

---@param lines                         string[]
---@param callback                      fun(bufnr: integer): nil
---@return nil
local function with_buffer(lines, callback)
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  local previous_bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
  local bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  vim.api.nvim_win_set_buf(winnr, bufnr)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.api.nvim_set_option_value("expandtab", true, { buf = bufnr })
  vim.api.nvim_set_option_value("shiftwidth", 2, { buf = bufnr })
  vim.api.nvim_set_option_value("tabstop", 2, { buf = bufnr })

  local ok, err = pcall(callback, bufnr)
  if vim.api.nvim_buf_is_valid(previous_bufnr) then
    vim.api.nvim_win_set_buf(winnr, previous_bufnr)
  end
  if vim.api.nvim_buf_is_valid(bufnr) then
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end
  if not ok then
    error(err, 0)
  end
end

---@param keys                          string
---@return nil
local function feedkeys(keys)
  local encoded = vim.api.nvim_replace_termcodes(keys, true, false, true) ---@type string
  vim.api.nvim_feedkeys(encoded, "xt", false)
end

---@param expected                      string[]
---@param bufnr                         integer
---@param message                       string
---@return nil
local function assert_lines(expected, bufnr, message)
  local actual = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false) ---@type string[]
  t.assert_eq(vim.inspect(expected), vim.inspect(actual), message)
end

t:test("dressing keeps action implementation lazy", function()
  t.assert_nil(package.loaded["era.m.splitjoin.action"], "action loaded during dressing")
end)

t:test("split resolves the smallest bracket region", function()
  with_buffer({ [[call(alpha, nested(one, two), "x,y", omega,)]] }, function(bufnr)
    vim.api.nvim_win_set_cursor(0, { 1, 20 })
    Splitjoin.split()
    assert_lines({ "call(alpha, nested(", "  one,", "  two", [[), "x,y", omega,)]] }, bufnr, "smallest region")
  end)
end)

t:test("split keeps malformed bracket scanning within the interaction budget", function()
  local count = 20000 ---@type integer
  local prefix = string.rep("[", count) .. string.rep(")", count) .. " call" ---@type string
  with_buffer({ prefix .. "(alpha, beta)" }, function(bufnr)
    vim.api.nvim_win_set_cursor(0, { 1, #prefix + 2 })
    local started = vim.uv.hrtime() ---@type integer
    Splitjoin.split()
    local elapsed_ms = (vim.uv.hrtime() - started) / 1e6 ---@type number

    assert_lines({ prefix .. "(", "  alpha,", "  beta", ")" }, bufnr, "region after malformed prefix")
    t.assert_true(elapsed_ms < 100, string.format("linear split took %.3fms", elapsed_ms))
  end)
end)

t:test("normal mappings split and join arguments", function()
  with_buffer({ "local value = call(alpha, beta)" }, function(bufnr)
    vim.api.nvim_win_set_cursor(0, { 1, 20 })
    feedkeys("gS")
    assert_lines({ "local value = call(", "  alpha,", "  beta", ")" }, bufnr, "split")

    feedkeys("gJ")
    assert_lines({ "local value = call(alpha, beta)" }, bufnr, "join")
  end)
end)

t:test("split is one undo step", function()
  with_buffer({ "call(alpha, beta)" }, function(bufnr)
    vim.api.nvim_win_set_cursor(0, { 1, 6 })
    feedkeys("gS")
    feedkeys("u")
    assert_lines({ "call(alpha, beta)" }, bufnr, "undo")
  end)
end)

t:test("join is one undo step", function()
  local original = { "call(", "  alpha,", "  beta", ")" } ---@type string[]
  with_buffer(original, function(bufnr)
    vim.api.nvim_win_set_cursor(0, { 2, 3 })
    feedkeys("gJ")
    feedkeys("u")
    assert_lines(original, bufnr, "undo")
  end)
end)

t:test("split preserves byte positions in the later part of a buffer", function()
  local target = "local 文本 = call(alpha, beta)" ---@type string
  with_buffer({ "local preface = true", target }, function(bufnr)
    local alpha = assert(target:find("alpha", 1, true)) ---@type integer
    vim.api.nvim_win_set_cursor(0, { 2, alpha - 1 })
    feedkeys("gS")
    assert_lines({ "local preface = true", "local 文本 = call(", "  alpha,", "  beta", ")" }, bufnr, "offset")
  end)
end)

t:test("split ignores nested and quoted separators and preserves a trailing comma", function()
  with_buffer({ [[call(alpha, nested(one, two), "x,y", { key = "a,b" }, omega,)]] }, function(bufnr)
    vim.api.nvim_win_set_cursor(0, { 1, 6 })
    feedkeys("gS")
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
end)

t:test("split ignores quoted closing brackets and escaped quotes", function()
  with_buffer({ [[call(alpha, ")", "a\",b", beta)]] }, function(bufnr)
    vim.api.nvim_win_set_cursor(0, { 1, 6 })
    feedkeys("gS")
    assert_lines({ "call(", "  alpha,", '  ")",', [[  "a\",b",]], "  beta", ")" }, bufnr, "quoted split")
  end)
end)

t:test("split and join preserve line comment leaders", function()
  with_buffer({ "  -- call(alpha, beta)" }, function(bufnr)
    vim.api.nvim_set_option_value("commentstring", "-- %s", { buf = bufnr })
    vim.api.nvim_set_option_value("comments", "b:--", { buf = bufnr })
    vim.api.nvim_win_set_cursor(0, { 1, 12 })

    feedkeys("gS")
    assert_lines({ "  -- call(", "  --   alpha,", "  --   beta", "  -- )" }, bufnr, "comment split")

    feedkeys("gJ")
    assert_lines({ "  -- call(alpha, beta)" }, bufnr, "comment join")
  end)
end)

t:test("visual mapping limits transformation to the selected region", function()
  with_buffer({ "first(a, b) second(c, d)" }, function(bufnr)
    vim.api.nvim_win_set_cursor(0, { 1, 18 })
    vim.cmd("normal! v5l")
    feedkeys("gS")
    assert_lines({ "first(a, b) second(", "  c,", "  d", ")" }, bufnr, "selected region")
  end)
end)

t:test("split normalizes an already multiline region", function()
  with_buffer({ "call(", "  alpha,", "  beta", ")" }, function(bufnr)
    vim.api.nvim_win_set_cursor(0, { 2, 3 })
    feedkeys("gS")
    assert_lines({ "call(", "  alpha,", "  beta", ")" }, bufnr, "normalized split")
  end)
end)

t:test("normal operator supports dot repeat", function()
  with_buffer({ "call(a, b) call(c, d)" }, function(bufnr)
    vim.api.nvim_win_set_cursor(0, { 1, 6 })
    feedkeys("gS")
    vim.api.nvim_win_set_cursor(0, { 4, 8 })
    feedkeys(".")
    assert_lines({ "call(", "  a,", "  b", ") call(", "  c,", "  d", ")" }, bufnr, "dot repeat")
  end)
end)

t:run()
