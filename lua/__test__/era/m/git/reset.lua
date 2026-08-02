---@diagnostic disable: undefined-global
--- Run with: nvim -l lua/__test__/era/m/git/reset.lua

local bootstrap = require("__test__.bootstrap")
local harness = require("__test__.harness")

local t = harness.new("era.m.git.reset")
bootstrap.with_stl_c(t)
bootstrap.with_global(t, "stl", { c = { Ticker = {
  new = function()
    return {}
  end,
} } })
bootstrap.with_global(t, "era", {
  m = { git = { diff = require("era.m.git.diff"), staging = require("era.m.git.staging") } },
})

local staging = era.m.git.staging
local buffer = assert(loadfile("lua/era/m/git/buffer.lua"))() ---@type era.m.git.buffer

---@param fn                            function
---@param name                          string
---@return any
local function upvalue(fn, name)
  for index = 1, 50 do
    local current, value = debug.getupvalue(fn, index)
    if not current then
      break
    end
    if current == name then
      return value
    end
  end
  error("missing upvalue: " .. name)
end

local cache = upvalue(buffer.reset_hunk, "cache") ---@type table<integer, era.m.git.buffer.ICache>

---@param index_text                    string
---@param buffer_text                   string
---@return integer
local function setup(index_text, buffer_text)
  local bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  staging.replace_buffer_text(bufnr, buffer_text)
  cache[bufnr] = {
    index_document = staging.from_text(index_text),
    untracked = false,
  }
  return bufnr
end

---@param bufnr                         integer
---@return string
local function text(bufnr)
  return staging.from_buffer(bufnr).text
end

t:test("selection reset: unequal hunk is reverted as a whole", function()
  local bufnr = setup("b\nd\n", "a\na\na\n")
  local ok = buffer.reset_hunk(bufnr, { 2, 2 })
  t.assert_true(ok, "reset")
  t.assert_eq("b\nd\n", text(bufnr), "whole touched hunk")
  vim.api.nvim_buf_delete(bufnr, { force = true })
end)

t:test("selection reset: equal-length hunk is still reverted as a whole", function()
  local bufnr = setup("a\nb\n", "A\nB\n")
  local ok = buffer.reset_hunk(bufnr, { 1, 1 })
  t.assert_true(ok, "reset")
  t.assert_eq("a\nb\n", text(bufnr), "whole touched hunk")
  vim.api.nvim_buf_delete(bufnr, { force = true })
end)

t:test("selection reset: untouched hunks remain in the working document", function()
  local bufnr = setup("a\nb\nc\nd\n", "A\nb\nc\nD\n")
  local ok = buffer.reset_hunk(bufnr, { 1, 1 })
  t.assert_true(ok, "reset")
  t.assert_eq("a\nb\nc\nD\n", text(bufnr), "second hunk remains")
  vim.api.nvim_buf_delete(bufnr, { force = true })
end)

t:test("selection reset: pure deletion returns at the correct anchor", function()
  local bufnr = setup("a\nb\nc\nd\n", "a\nc\nd\n")
  local ok = buffer.reset_hunk(bufnr, { 1, 1 })
  t.assert_true(ok, "reset")
  t.assert_eq("a\nb\nc\nd\n", text(bufnr), "order")
  vim.api.nvim_buf_delete(bufnr, { force = true })
end)

t:test("selection reset: final newline follows the reverted hunk", function()
  local bufnr = setup("a\nb\n", "a\nB")
  local ok = buffer.reset_hunk(bufnr, { 2, 2 })
  t.assert_true(ok, "reset")
  t.assert_eq("a\nb\n", text(bufnr), "newline")
  vim.api.nvim_buf_delete(bufnr, { force = true })
end)

t:test("reset_buffer: index document is the baseline without a sentinel line", function()
  local bufnr = setup("one\ntwo\n", "ONE\ntwo\n")
  t.assert_true(buffer.reset_buffer(bufnr), "reset")
  t.assert_eq("one\ntwo\n", text(bufnr), "index text")
  t.assert_eq(2, vim.api.nvim_buf_line_count(bufnr), "no blank sentinel line")
  vim.api.nvim_buf_delete(bufnr, { force = true })
end)

t:run()
