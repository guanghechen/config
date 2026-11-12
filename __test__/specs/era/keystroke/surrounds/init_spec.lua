local bootstrap = require("__test__.support.bootstrap")
local harness = require("__test__.support.harness")
local textobject = require("__test__.support.textobject")

local t = harness.new()

bootstrap.with_runtime(t, {
  stl = {
    filetype = require("stl.filetype"),
    nvim = {
      fn = require("stl.nvim.fn"),
    },
  },
  era = {
    keystroke = require("era.keystroke"),
  },
})

local Surrounds = era.keystroke.surrounds
local Buffer = require("era.keystroke.surrounds.buffer")
local Keymap = require("era.keystroke.surrounds.keymap")
Surrounds.setup()

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

t:test("keymaps follow buffer eligibility", function()
  local bufnr = t:buffer({ "alpha" }, { filetype = "lua", current = true })
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

t:test("detach preserves mappings replaced by another owner", function()
  local bufnr = t:buffer({ "alpha" }, { filetype = "lua", current = true })
  vim.keymap.set("n", "gsa", function() end, { buffer = bufnr, desc = "surrounds: add" })
  vim.api.nvim_set_option_value("readonly", true, { buf = bufnr })

  t.assert_eq("surrounds: add", get_keymap_desc(bufnr, "n", "gsa"), "foreign mapping with matching description")
  t.assert_false(has_keymap(bufnr, "n", "gsd"), "owned mapping removed")
end)

t:test("buffer rename preserves attachment ownership", function()
  local bufnr = t:buffer({ "alpha" }, { filetype = "lua", current = true })
  vim.api.nvim_buf_set_name(bufnr, "surrounds-before-" .. tostring(bufnr))
  vim.wait(10)
  vim.api.nvim_buf_set_name(bufnr, "surrounds-after-" .. tostring(bufnr))
  vim.wait(10)

  vim.api.nvim_set_option_value("readonly", true, { buf = bufnr })
  t.assert_false(has_keymap(bufnr, "n", "gsa"), "renamed readonly buffer")
end)

t:test("unlisted buffer wipeout releases attachment state", function()
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  local previous_bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
  local bufnr = t:buffer(nil, { filetype = "lua", current = true }) ---@type integer
  t.assert_true(has_keymap(bufnr, "n", "gsa"), "unlisted buffer attached")

  vim.api.nvim_win_set_buf(winnr, previous_bufnr)
  vim.api.nvim_buf_delete(bufnr, { force = true })
  vim.wait(10)

  local ok = pcall(Keymap.refresh, bufnr)
  t.assert_true(ok, "wiped buffer state released")
end)

t:test("neighborhood conversions preserve empty and multiline regions", function()
  t:buffer({ "alpha", "beta", "gamma" }, { filetype = "lua", current = true })
  local reference = { from = { line = 2, col = 2 } } ---@type era.keystroke.surrounds.IRegion
  local neighborhood = Buffer.get_neighborhood(reference, 1)

  local empty_span = neighborhood.region_to_span(reference)
  t.assert_eq(empty_span.from, empty_span.to, "empty region span")
  t.assert_same(reference, neighborhood.span_to_region(empty_span), "empty region round trip")

  local multiline = {
    from = { line = 1, col = 2 },
    to = { line = 3, col = 3 },
  } ---@type era.keystroke.surrounds.IRegion
  ---@diagnostic disable-next-line: assign-type-mismatch
  local multiline_span = neighborhood.region_to_span(multiline)
  t.assert_eq(
    vim.inspect(multiline),
    ---@diagnostic disable-next-line: param-type-mismatch
    vim.inspect(neighborhood.span_to_region(multiline_span)),
    "multiline region round trip"
  )
end)

t:test("add delete and replace surrounding", function()
  local bufnr = t:buffer({ "alpha" }, { filetype = "lua", current = true })
  Keymap.refresh(bufnr)
  vim.api.nvim_win_set_cursor(0, { 1, 0 })

  textobject.feed("gsaiw)")
  t.assert_eq("(alpha)", vim.api.nvim_get_current_line(), "add")

  textobject.feed("gsr)]")
  t.assert_eq("[alpha]", vim.api.nvim_get_current_line(), "replace")

  textobject.feed("gsd]")
  t.assert_eq("alpha", vim.api.nvim_get_current_line(), "delete")
end)

t:test("linewise add respects selection type", function()
  local bufnr = t:buffer({ "alpha", "beta" }, { filetype = "lua", current = true })
  Keymap.refresh(bufnr)
  vim.api.nvim_set_option_value("expandtab", true, { buf = bufnr })
  vim.api.nvim_set_option_value("shiftwidth", 2, { buf = bufnr })
  vim.api.nvim_win_set_cursor(0, { 1, 0 })

  textobject.feed("Vjgsa}")
  t.assert_same({ "{", "  alpha", "  beta", "}" }, vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "linewise add")

  vim.api.nvim_win_set_cursor(0, { 2, 2 })
  textobject.feed("gsd}")
  t.assert_same({ "alpha", "beta" }, vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "linewise delete")
end)

t:test("blockwise add surrounds every selected row", function()
  local bufnr = t:buffer({ "aa", "bb" }, { filetype = "lua", current = true })
  Keymap.refresh(bufnr)
  vim.api.nvim_win_set_cursor(0, { 1, 0 })

  textobject.feed("<C-v>jgsa)")
  t.assert_same({ "(a)a", "(b)b" }, vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "blockwise add")
end)

t:test("function output and find actions", function()
  local bufnr = t:buffer({ "alpha" }, { filetype = "lua", current = true })
  Keymap.refresh(bufnr)
  vim.api.nvim_win_set_cursor(0, { 1, 0 })

  textobject.feed("gsaiwffname<CR>")
  t.assert_eq("fname(alpha)", vim.api.nvim_get_current_line(), "function output")

  textobject.feed("gsff")
  t.assert_same({ 1, 11 }, vim.api.nvim_win_get_cursor(0), "find right")

  textobject.feed("gsFf")
  t.assert_same({ 1, 5 }, vim.api.nvim_win_get_cursor(0), "find left")
end)

t:test("delete respects count and cover-or-next search", function()
  local bufnr = t:buffer({ "(a(b(c)b)a)" }, { filetype = "lua", current = true })
  Keymap.refresh(bufnr)
  vim.api.nvim_win_set_cursor(0, { 1, 5 })

  textobject.feed("2gsd)")
  t.assert_eq("(ab(c)ba)", vim.api.nvim_get_current_line(), "nested count")

  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "(a) bbb (c)" })
  vim.api.nvim_win_set_cursor(0, { 1, 5 })
  textobject.feed("gsd)")
  t.assert_eq("(a) bbb c", vim.api.nvim_get_current_line(), "cover-or-next fallback")
end)

t:test("add respects count and dot repeat", function()
  local bufnr = t:buffer({ "alpha beta" }, { filetype = "lua", current = true })
  Keymap.refresh(bufnr)
  vim.api.nvim_win_set_cursor(0, { 1, 0 })

  textobject.feed("2gsaiw)")
  t.assert_eq("((alpha)) beta", vim.api.nvim_get_current_line(), "count")

  vim.api.nvim_win_set_cursor(0, { 1, 10 })
  textobject.feed(".")
  t.assert_eq("((alpha)) ((beta))", vim.api.nvim_get_current_line(), "dot repeat")
end)

t:test("keymaps come back when :bdelete reopens the same buffer number", function()
  local path = t:tempdir() .. "/reopened.lua"
  vim.fn.writefile({ "alpha" }, path)
  local previous_bufnr = vim.api.nvim_get_current_buf() ---@type integer
  local bufnrs = {} ---@type integer[]
  t:defer(function()
    if vim.api.nvim_buf_is_valid(previous_bufnr) then
      vim.api.nvim_win_set_buf(0, previous_bufnr)
    end
    for _, bufnr in ipairs(bufnrs) do
      if vim.api.nvim_buf_is_valid(bufnr) then
        vim.api.nvim_buf_delete(bufnr, { force = true })
      end
    end
  end)
  -- Filetype detection is off here; setting it stands in for the detection of a real start.
  local function open()
    vim.cmd.edit(vim.fn.fnameescape(path))
    local bufnr = vim.api.nvim_get_current_buf() ---@type integer
    vim.api.nvim_set_option_value("filetype", "lua", { buf = bufnr })
    return bufnr
  end

  local bufnr = open()
  bufnrs[#bufnrs + 1] = bufnr
  t.assert_true(has_keymap(bufnr, "n", "gsa"), "attached")
  vim.cmd.enew()
  bufnrs[#bufnrs + 1] = vim.api.nvim_get_current_buf()
  vim.cmd.bdelete(tostring(bufnr))
  t.assert_eq(bufnr, open(), "the same buffer number")
  t.assert_true(has_keymap(bufnr, "n", "gsa"), "attached again")
end)

t:run()
