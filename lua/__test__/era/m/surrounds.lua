---@diagnostic disable: undefined-global
--- Test for era.m.surrounds
--- Run with: nvim -l lua/__test__/era/m/surrounds.lua

local bootstrap = require("__test__.bootstrap")
local harness = require("__test__.harness")

local t = harness.new("era.m.surrounds")

bootstrap.with_runtime(t, {
  stl = {
    filetype = require("stl.filetype"),
    nvim = {
      fn = require("stl.nvim.fn"),
    },
  },
  era = {
    m = {},
  },
})

local Surrounds = require("era.m.surrounds")
local Buffer = require("era.m.surrounds.buffer")
local Keymap = require("era.m.surrounds.keymap")
era.m.surrounds = Surrounds
Surrounds.setup()

---@param lines                         string[]
---@param callback                      fun(bufnr: integer): nil
---@return nil
local function with_buffer(lines, callback)
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  local previous_bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
  local bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  vim.api.nvim_win_set_buf(winnr, bufnr)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.api.nvim_set_option_value("filetype", "lua", { buf = bufnr })

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

---@param bufnr                         integer
---@param mode                          string
---@param key                           string
---@return boolean
local function has_keymap(bufnr, mode, key)
  for _, keymap in ipairs(vim.api.nvim_buf_get_keymap(bufnr, mode)) do
    if keymap.lhs == key then
      return true
    end
  end
  return false
end

---@param bufnr                         integer
---@param mode                          string
---@param key                           string
---@return string|nil
local function get_keymap_desc(bufnr, mode, key)
  for _, keymap in ipairs(vim.api.nvim_buf_get_keymap(bufnr, mode)) do
    if keymap.lhs == key then
      return keymap.desc
    end
  end
end

---@param mode                          string
---@param key                           string
---@return boolean
local function has_global_keymap(mode, key)
  for _, keymap in ipairs(vim.api.nvim_get_keymap(mode)) do
    if keymap.lhs == key then
      return true
    end
  end
  return false
end

---@param keys                          string
---@return nil
local function feedkeys(keys)
  local encoded = vim.api.nvim_replace_termcodes(keys, true, false, true) ---@type string
  vim.api.nvim_feedkeys(encoded, "xt", false)
end

---@return string
local function current_line()
  return vim.api.nvim_get_current_line()
end

---@param expected                      string[]
---@param actual                        string[]
---@param message                       string
---@return nil
local function assert_lines(expected, actual, message)
  t.assert_eq(vim.inspect(expected), vim.inspect(actual), message)
end

t:test("keymaps follow buffer eligibility", function()
  with_buffer({ "alpha" }, function(bufnr)
    t.assert_false(has_global_keymap("n", "gsa"), "no global mapping")
    t.assert_true(has_keymap(bufnr, "n", "gsa"), "editable source buffer")

    vim.api.nvim_set_option_value("readonly", true, { buf = bufnr })
    t.assert_false(has_keymap(bufnr, "n", "gsa"), "readonly buffer")
    t.assert_false(has_keymap(bufnr, "x", "gsa"), "readonly visual mapping")

    vim.api.nvim_set_option_value("readonly", false, { buf = bufnr })
    vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })
    t.assert_false(has_keymap(bufnr, "n", "gsa"), "non-modifiable buffer")

    vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })
    vim.api.nvim_set_option_value("filetype", stl.filetype.DIFFVIEW_CHANGES, { buf = bufnr })
    vim.keymap.set("n", "gs", function() end, { buffer = bufnr })
    vim.keymap.set("n", "gr", function() end, { buffer = bufnr })
    t.assert_false(has_keymap(bufnr, "n", "gsa"), "diffview changes buffer")
    t.assert_true(has_keymap(bufnr, "n", "gs"), "diffview gs remains")
    t.assert_true(has_keymap(bufnr, "n", "gr"), "diffview gr remains")

    vim.api.nvim_set_option_value("filetype", stl.filetype.NOTEPAD, { buf = bufnr })
    vim.api.nvim_set_option_value("buftype", "nofile", { buf = bufnr })
    t.assert_true(has_keymap(bufnr, "n", "gsa"), "editable nofile buffer")
  end)
end)

t:test("detach preserves mappings replaced by another owner", function()
  with_buffer({ "alpha" }, function(bufnr)
    vim.keymap.set("n", "gsa", function() end, { buffer = bufnr, desc = "surrounds: add" })
    vim.api.nvim_set_option_value("readonly", true, { buf = bufnr })

    t.assert_eq("surrounds: add", get_keymap_desc(bufnr, "n", "gsa"), "foreign mapping with matching description")
    t.assert_false(has_keymap(bufnr, "n", "gsd"), "owned mapping removed")
  end)
end)

t:test("buffer rename preserves attachment ownership", function()
  with_buffer({ "alpha" }, function(bufnr)
    vim.api.nvim_buf_set_name(bufnr, "surrounds-before-" .. tostring(bufnr))
    vim.wait(10)
    vim.api.nvim_buf_set_name(bufnr, "surrounds-after-" .. tostring(bufnr))
    vim.wait(10)

    vim.api.nvim_set_option_value("readonly", true, { buf = bufnr })
    t.assert_false(has_keymap(bufnr, "n", "gsa"), "renamed readonly buffer")
  end)
end)

t:test("unlisted buffer wipeout releases attachment state", function()
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  local previous_bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
  local bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  vim.api.nvim_win_set_buf(winnr, bufnr)
  vim.api.nvim_set_option_value("filetype", "lua", { buf = bufnr })
  t.assert_true(has_keymap(bufnr, "n", "gsa"), "unlisted buffer attached")

  vim.api.nvim_win_set_buf(winnr, previous_bufnr)
  vim.api.nvim_buf_delete(bufnr, { force = true })
  vim.wait(10)

  local ok = pcall(Keymap.refresh, bufnr)
  t.assert_true(ok, "wiped buffer state released")
end)

t:test("neighborhood conversions preserve empty and multiline regions", function()
  with_buffer({ "alpha", "beta", "gamma" }, function()
    local reference = { from = { line = 2, col = 2 } } ---@type era.m.surrounds.IRegion
    local neighborhood = Buffer.get_neighborhood(reference, 1)

    local empty_span = neighborhood.region_to_span(reference)
    t.assert_eq(empty_span.from, empty_span.to, "empty region span")
    t.assert_eq(vim.inspect(reference), vim.inspect(neighborhood.span_to_region(empty_span)), "empty region round trip")

    local multiline = {
      from = { line = 1, col = 2 },
      to = { line = 3, col = 3 },
    } ---@type era.m.surrounds.IRegion
    ---@diagnostic disable-next-line: assign-type-mismatch
    local multiline_span = neighborhood.region_to_span(multiline)
    t.assert_eq(
      vim.inspect(multiline),
      ---@diagnostic disable-next-line: param-type-mismatch
      vim.inspect(neighborhood.span_to_region(multiline_span)),
      "multiline region round trip"
    )
  end)
end)

t:test("add delete and replace surrounding", function()
  with_buffer({ "alpha" }, function(bufnr)
    Keymap.refresh(bufnr)
    vim.api.nvim_win_set_cursor(0, { 1, 0 })

    feedkeys("gsaiw)")
    t.assert_eq("(alpha)", current_line(), "add")

    feedkeys("gsr)]")
    t.assert_eq("[alpha]", current_line(), "replace")

    feedkeys("gsd]")
    t.assert_eq("alpha", current_line(), "delete")
  end)
end)

t:test("linewise add respects selection type", function()
  with_buffer({ "alpha", "beta" }, function(bufnr)
    Keymap.refresh(bufnr)
    vim.api.nvim_set_option_value("expandtab", true, { buf = bufnr })
    vim.api.nvim_set_option_value("shiftwidth", 2, { buf = bufnr })
    vim.api.nvim_win_set_cursor(0, { 1, 0 })

    feedkeys("Vjgsa}")
    assert_lines({ "{", "  alpha", "  beta", "}" }, vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "linewise add")

    vim.api.nvim_win_set_cursor(0, { 2, 2 })
    feedkeys("gsd}")
    assert_lines({ "alpha", "beta" }, vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "linewise delete")
  end)
end)

t:test("blockwise add surrounds every selected row", function()
  with_buffer({ "aa", "bb" }, function(bufnr)
    Keymap.refresh(bufnr)
    vim.api.nvim_win_set_cursor(0, { 1, 0 })

    feedkeys("<C-v>jgsa)")
    assert_lines({ "(a)a", "(b)b" }, vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "blockwise add")
  end)
end)

t:test("function output and find actions", function()
  with_buffer({ "alpha" }, function(bufnr)
    Keymap.refresh(bufnr)
    vim.api.nvim_win_set_cursor(0, { 1, 0 })

    feedkeys("gsaiwffname<CR>")
    t.assert_eq("fname(alpha)", current_line(), "function output")

    feedkeys("gsff")
    t.assert_eq(vim.inspect({ 1, 11 }), vim.inspect(vim.api.nvim_win_get_cursor(0)), "find right")

    feedkeys("gsFf")
    t.assert_eq(vim.inspect({ 1, 5 }), vim.inspect(vim.api.nvim_win_get_cursor(0)), "find left")
  end)
end)

t:test("delete respects count and cover-or-next search", function()
  with_buffer({ "(a(b(c)b)a)" }, function(bufnr)
    Keymap.refresh(bufnr)
    vim.api.nvim_win_set_cursor(0, { 1, 5 })

    feedkeys("2gsd)")
    t.assert_eq("(ab(c)ba)", current_line(), "nested count")

    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "(a) bbb (c)" })
    vim.api.nvim_win_set_cursor(0, { 1, 5 })
    feedkeys("gsd)")
    t.assert_eq("(a) bbb c", current_line(), "cover-or-next fallback")
  end)
end)

t:test("add respects count and dot repeat", function()
  with_buffer({ "alpha beta" }, function(bufnr)
    Keymap.refresh(bufnr)
    vim.api.nvim_win_set_cursor(0, { 1, 0 })

    feedkeys("2gsaiw)")
    t.assert_eq("((alpha)) beta", current_line(), "count")

    vim.api.nvim_win_set_cursor(0, { 1, 10 })
    feedkeys(".")
    t.assert_eq("((alpha)) ((beta))", current_line(), "dot repeat")
  end)
end)

t:run()
