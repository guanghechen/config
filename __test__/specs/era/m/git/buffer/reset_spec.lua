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

-- Resetting the selected lines restores every hunk they touch from the index document.
for _, case in ipairs({
  {
    name = "selection reset: unequal hunk is reverted as a whole",
    index = "b\nd\n",
    buffer = "a\na\na\n",
    range = { 2, 2 },
    expected = "b\nd\n",
    message = "whole touched hunk",
  },
  {
    name = "selection reset: equal-length hunk is still reverted as a whole",
    index = "a\nb\n",
    buffer = "A\nB\n",
    range = { 1, 1 },
    expected = "a\nb\n",
    message = "whole touched hunk",
  },
  {
    name = "selection reset: untouched hunks remain in the working document",
    index = "a\nb\nc\nd\n",
    buffer = "A\nb\nc\nD\n",
    range = { 1, 1 },
    expected = "a\nb\nc\nD\n",
    message = "second hunk remains",
  },
  {
    name = "selection reset: pure deletion returns at the correct anchor",
    index = "a\nb\nc\nd\n",
    buffer = "a\nc\nd\n",
    range = { 1, 1 },
    expected = "a\nb\nc\nd\n",
    message = "order",
  },
  {
    name = "reset_hunk restores pure deletions at their anchors",
    index = "a\nb\nc\n",
    buffer = "b\nc\n",
    range = { 1, 1 },
    expected = "a\nb\nc\n",
    message = "buffer order",
  },
  {
    name = "selection reset: final newline follows the reverted hunk",
    index = "a\nb\n",
    buffer = "a\nB",
    range = { 2, 2 },
    expected = "a\nb\n",
    message = "newline",
  },
  {
    name = "reset_hunk preserves unchanged gaps between nearby hunks",
    index = 'local M = {}\nfunction M.hello()\n  return "hi"\nend\nreturn M\n',
    buffer = 'local M = {}\nfunction M.hello()\n  return "changed"\nend\nfunction M.extra() end\nreturn M\n',
    range = { 3, 5 },
    expected = 'local M = {}\nfunction M.hello()\n  return "hi"\nend\nreturn M\n',
    message = "HEAD round-trip",
  },
}) do
  t:test(case.name, function()
    local bufnr = setup(case.index, case.buffer)
    local ok = buffer.reset_hunk(bufnr, case.range)
    t.assert_true(ok, "reset")
    t.assert_eq(case.expected, text(bufnr), case.message)
  end)
end

t:test("reset_hunk: a refusal says where it found nothing to reset", function()
  local bufnr = setup("a\nb\n", "a\nb\n")
  local reasons = {} ---@type string[]
  for _, call in ipairs({ { t:buffer() }, { bufnr }, { bufnr, { 1, 2 } } }) do
    local ok, reason = buffer.reset_hunk(call[1], call[2])
    t.assert_false(ok, "refused")
    reasons[#reasons + 1] = reason
  end

  t.assert_same({
    "Not a Git-tracked buffer, or its Git state is still loading",
    "No hunk at cursor",
    "No unstaged change in the selection",
  }, reasons)
end)

t:test("reset_buffer: index document is the baseline without a sentinel line", function()
  local bufnr = setup("one\ntwo\n", "ONE\ntwo\n")
  t.assert_true(buffer.reset_buffer(bufnr), "reset")
  t.assert_eq("one\ntwo\n", text(bufnr), "index text")
  t.assert_eq(2, vim.api.nvim_buf_line_count(bufnr), "no blank sentinel line")
end)

t:run()
