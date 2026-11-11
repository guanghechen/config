local git_buffer = require("__test__.support.git_buffer")
local harness = require("__test__.support.harness")

local t = harness.new()
local buffer = git_buffer.load(t, {
  era = { m = { git = { diff = require("era.m.git.diff"), staging = require("era.m.git.staging") } } },
})
local staging = era.m.git.staging
local cache = git_buffer.cache(buffer)

---@param index_text                    string
---@param buffer_text                   string
---@return integer
local function setup(index_text, buffer_text)
  local bufnr = t:buffer()
  staging.replace_buffer_text(bufnr, buffer_text)
  ---@diagnostic disable-next-line: missing-fields
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
end)

t:test("selection reset: equal-length hunk is still reverted as a whole", function()
  local bufnr = setup("a\nb\n", "A\nB\n")
  local ok = buffer.reset_hunk(bufnr, { 1, 1 })
  t.assert_true(ok, "reset")
  t.assert_eq("a\nb\n", text(bufnr), "whole touched hunk")
end)

t:test("selection reset: untouched hunks remain in the working document", function()
  local bufnr = setup("a\nb\nc\nd\n", "A\nb\nc\nD\n")
  local ok = buffer.reset_hunk(bufnr, { 1, 1 })
  t.assert_true(ok, "reset")
  t.assert_eq("a\nb\nc\nD\n", text(bufnr), "second hunk remains")
end)

t:test("selection reset: pure deletion returns at the correct anchor", function()
  local bufnr = setup("a\nb\nc\nd\n", "a\nc\nd\n")
  local ok = buffer.reset_hunk(bufnr, { 1, 1 })
  t.assert_true(ok, "reset")
  t.assert_eq("a\nb\nc\nd\n", text(bufnr), "order")
end)

t:test("selection reset: final newline follows the reverted hunk", function()
  local bufnr = setup("a\nb\n", "a\nB")
  local ok = buffer.reset_hunk(bufnr, { 2, 2 })
  t.assert_true(ok, "reset")
  t.assert_eq("a\nb\n", text(bufnr), "newline")
end)

t:test("reset_buffer: index document is the baseline without a sentinel line", function()
  local bufnr = setup("one\ntwo\n", "ONE\ntwo\n")
  t.assert_true(buffer.reset_buffer(bufnr), "reset")
  t.assert_eq("one\ntwo\n", text(bufnr), "index text")
  t.assert_eq(2, vim.api.nvim_buf_line_count(bufnr), "no blank sentinel line")
end)

t:run()
