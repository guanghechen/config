--- Run with: nvim -l __test__/run.lua __test__/specs/era/m/git/staging_spec.lua
---@diagnostic disable: undefined-global

local harness = require("__test__.support.harness")
local diff = require("era.m.git.diff")
local staging = require("era.m.git.staging")

local t = harness.new("era.m.git.staging")

---@param original                      string
---@param modified                      string
---@return era.m.git.Document
---@return era.m.git.Document
---@return era.m.git.Hunk[]
local function documents(original, modified)
  local original_document = staging.from_text(original) ---@type era.m.git.Document
  local modified_document = staging.from_text(modified) ---@type era.m.git.Document
  local hunks = diff.run_diff(original_document.lines, modified_document.lines) ---@type era.m.git.Hunk[]
  return original_document, modified_document, hunks
end

t:test("apply_line_changes: complete selection reproduces the modified document", function()
  local cases = {
    { "a\nb\n", "a\nB\n" },
    { "b\nc\n", "a\nb\nc\n" },
    { "a\nb\nc\n", "a\nc\n" },
    { "a\nb\n", "a\nb" },
    { "a\nb", "a\nb\n" },
    { "", "a\n" },
    { "a\n", "" },
    { "a", "" },
    { "a\nb", "" },
  }

  for _, case in ipairs(cases) do
    local original, modified, hunks = documents(case[1], case[2])
    t.assert_eq(modified.text, staging.apply_line_changes(original, modified, hunks), vim.inspect(case))
  end
end)

t:test("intersect: equal-length changes narrow line by line", function()
  local original, modified, hunks = documents("a\nb\nc\n", "a\nB\nC\n")
  t.assert_eq(1, #hunks, "one hunk")

  local selected = assert(staging.intersect(hunks[1], 2, 2))
  t.assert_eq("a\nB\nc\n", staging.apply_line_changes(original, modified, { selected }), "line 2 only")
end)

t:test("intersect: unequal changes keep the complete original span", function()
  local original, modified, hunks = documents("a\nb\nd\n", "a\nX\nY\nd\n")
  t.assert_eq(1, #hunks, "one hunk")

  local selected = assert(staging.intersect(hunks[1], 2, 2))
  t.assert_eq(1, selected.removed.count, "complete original side")
  t.assert_eq("a\nX\nd\n", staging.apply_line_changes(original, modified, { selected }), "selected modified line")
end)

t:test("intersect: a deletion is selected whole", function()
  local original, _, hunks = documents("a\nb\nc\nd\n", "a\nd\n")
  local selected = assert(staging.intersect(hunks[1], 1, 1))
  t.assert_eq(2, selected.removed.count, "whole deletion")
  t.assert_eq(
    "a\nd\n",
    staging.apply_line_changes(original, staging.from_text("a\nd\n"), { selected }),
    "whole deletion"
  )
end)

t:test("reset: every touched hunk is removed from the changes reapplied to index", function()
  local index_document, buffer_document, hunks = documents("b\nd\n", "a\na\na\n")
  local untouched = vim.tbl_filter(function(hunk)
    return not staging.touches(hunk, 2, 2)
  end, hunks)

  t.assert_eq("b\nd\n", staging.apply_line_changes(index_document, buffer_document, untouched), "whole touched hunk")
end)

t:test("documents: VS Code majority EOL normalization is preserved by encoding", function()
  local document = assert(staging.from_blob("a\r\nb\r\nc\n", "utf-8", "\n"))
  t.assert_eq("\r\n", document.eol, "majority CRLF")
  t.assert_eq("a\r\nb\r\nc\r\n", document.text, "normalized text")
  t.assert_eq(document.text, assert(staging.encode(document)), "encoded bytes")
end)

t:test("documents: file encoding and BOM round-trip", function()
  local latin1 = assert(vim.iconv("caf\195\169\n", "utf-8", "latin1"))
  local document = assert(staging.from_blob(latin1, "latin1", "\n"))
  t.assert_eq("caf\195\169\n", document.text, "decoded")
  t.assert_eq(latin1, assert(staging.encode(document)), "encoded")

  local utf8_bom = "\239\187\191hello\n"
  local bom_document = assert(staging.from_blob(utf8_bom, "utf-8", "\n"))
  t.assert_true(bom_document.bomb, "BOM detected")
  t.assert_eq(utf8_bom, assert(staging.encode(bom_document)), "BOM restored")
end)

t:test("replace_buffer_text: write preserves exact final-EOL bytes", function()
  local cases = { "", "\n", "a", "a\n" }

  for _, expected in ipairs(cases) do
    local filepath = vim.fn.tempname() ---@type string
    local bufnr = vim.api.nvim_create_buf(false, false) ---@type integer
    vim.api.nvim_buf_set_name(bufnr, filepath)
    staging.replace_buffer_text(bufnr, expected)
    vim.api.nvim_buf_call(bufnr, function()
      vim.cmd("silent write!")
    end)

    local file = assert(io.open(filepath, "rb"))
    local actual = file:read("*a") ---@type string
    file:close()
    t.assert_eq(expected, actual, string.format("bytes for %q", expected))

    vim.api.nvim_buf_delete(bufnr, { force = true })
    vim.fn.delete(filepath)
  end
end)

t:test("from_buffer: preserves document text without reparsing buffer lines", function()
  local cases = { "", "\n", "a", "a\n", "a\r\n" }

  for _, expected in ipairs(cases) do
    local bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
    vim.api.nvim_set_option_value("fileformat", expected:find("\r\n", 1, true) and "dos" or "unix", { buf = bufnr })
    staging.replace_buffer_text(bufnr, expected)

    local document = staging.from_buffer(bufnr)
    t.assert_eq(expected, document.text, string.format("text for %q", expected))
    t.assert_eq(expected, table.concat(document.lines, document.eol), string.format("lines for %q", expected))
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end
end)

t:run()
