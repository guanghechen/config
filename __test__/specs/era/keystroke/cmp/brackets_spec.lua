local harness = require("__test__.support.harness")
local runtime = require("__test__.support.cmp.runtime")
local fixture = require("__test__.support.cmp.fixture")
runtime.setup()
local t = harness.new()
local Item = require("era.keystroke.cmp.item")
local Edit = require("era.keystroke.cmp.edit")
local Brackets = require("era.keystroke.cmp.brackets")

t:test("auto-brackets preserve existing brackets and snippet syntax", function()
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "foo()" })
  local context = runtime.context("foo()", 3)
  local raw = { label = "foobar", kind = 3 }
  local plan = assert(Edit.plan(assert(Item.new(context, "lsp", raw)), context))
  Brackets.prepare(context, raw, plan)
  t.assert_eq("foobar", plan.main.newText, "existing parentheses")
  t.assert_eq(1, plan.cursor_offset, "cursor enters existing parentheses")

  context = runtime.context("foo")
  plan = assert(Edit.plan(assert(Item.new(context, "lsp", raw)), context))
  Brackets.prepare(context, raw, plan)
  t.assert_eq("foobar()", plan.main.newText, "new parentheses")
  t.assert_eq(-1, plan.cursor_offset, "cursor enters new parentheses")
end)

t:test("auto-brackets exclude imports, exceptions, selectors and blocked languages", function()
  for _, case in ipairs({
    { filetype = "python", line = "  from math import si", label = "sin" },
    { filetype = "python", line = "import pa", label = "path" },
    { filetype = "python", line = "except ValueErr", label = "ValueError" },
    { filetype = "typescript", line = "import { useSta", label = "useState" },
    { filetype = "typescriptreact", line = "import { useSta", label = "useState" },
    { filetype = "svelte", line = "  import { useSta", label = "useState" },
    { filetype = "rust", line = "use std::mem::dr", label = "drop" },
    { filetype = "rust", line = "dr", label = "drop" },
    { filetype = "cpp", line = "std::mo", label = "move" },
    { filetype = "ruby", line = "pu", label = "puts" },
    { filetype = "css", line = "a::be", label = "before" },
    { filetype = "scss", line = "a:ho { color: red; }", col = 4, label = "hover" },
    { filetype = "html", line = "a:ho", label = "hover" },
  }) do
    for _, kind in ipairs({ 3, 6 }) do
      local plan = fixture.bracket_plan(case.filetype, case.line, case.col, { label = case.label, kind = kind })
      local label = case.filetype .. ": " .. case.line
      t.assert_eq(case.label, plan.main.newText, label)
      t.assert_eq(false, plan.semantic_brackets, label .. " also excludes semantic resolution")
    end
  end
end)

t:test("auto-brackets use language delimiters and preserve supplied calls", function()
  for _, case in ipairs({
    { filetype = "python", line = "si", label = "sin", text = "sin()", offset = -1 },
    { filetype = "typescript", line = "useSta", label = "useState", text = "useState()", offset = -1 },
    { filetype = "css", line = "a { width: ca", label = "calc", text = "calc()", offset = -1 },
    { filetype = "sh", line = "pri", label = "printf", text = "printf ", offset = 0 },
    { filetype = "nix", line = "ma", label = "map", text = "map ", offset = 0 },
    { filetype = "wl", line = "Si", label = "Sin", text = "Sin[]", offset = -1 },
    { filetype = "tex", line = "te", label = "textbf", text = "textbf{}", offset = -1 },
    { filetype = "lua", line = "fo", label = "foo()", text = "foo()", offset = 0 },
    { filetype = "wl", line = "Si", label = "Sin[x]", text = "Sin[x]", offset = 0 },
    { filetype = "tex", line = "te", label = "\\textbf", text = "\\textbf", offset = 0 },
  }) do
    local plan = fixture.bracket_plan(case.filetype, case.line, nil, { label = case.label, kind = 3 })
    t.assert_eq(case.text, plan.main.newText, case.filetype .. " text")
    t.assert_eq(case.offset, plan.cursor_offset, case.filetype .. " cursor")
  end
end)

t:test("existing language delimiters retain cursor movement before filetype exclusions", function()
  for _, case in ipairs({
    { filetype = "rust", line = "dr()", col = 2, label = "drop" },
    { filetype = "sh", line = "pri value", col = 3, label = "printf" },
    { filetype = "wl", line = "Si[]", col = 2, label = "Sin" },
    { filetype = "tex", line = "te{}", col = 2, label = "textbf" },
  }) do
    for _, kind in ipairs({ 3, 6 }) do
      local plan = fixture.bracket_plan(case.filetype, case.line, case.col, { label = case.label, kind = kind })
      t.assert_eq(case.label, plan.main.newText, case.filetype .. " preserves delimiter")
      t.assert_eq(kind == 3 and 1 or 0, plan.cursor_offset, case.filetype .. " cursor")
      t.assert_eq(false, plan.semantic_brackets, case.filetype .. " needs no resolution")
    end
  end
end)

t:test("snippet brackets add a tabstop inside the language delimiters", function()
  for _, case in ipairs({
    { filetype = "lua", body = "call${1:Back}", text = "call${1:Back}($2)" },
    { filetype = "sh", body = "call$1", text = "call$1 $2" },
    { filetype = "wl", body = "call$1", text = "call$1[$2]" },
    { filetype = "tex", body = "call$1", text = "call$1{$2}" },
  }) do
    local plan = fixture.bracket_plan(
      case.filetype,
      "ca",
      nil,
      { label = "call", kind = 3, insertTextFormat = 2, insertText = case.body }
    )
    t.assert_eq(case.text, plan.main.newText, case.filetype)
    t.assert_true(Edit.snippet_text(plan.main.newText) ~= nil, "generated snippet remains valid")
  end
end)

t:test("kind and semantic resolution retain their separate language exclusions", function()
  for _, case in ipairs({
    { filetype = "lua", kind = 6, semantic = true },
    { filetype = "typescriptreact", kind = 3, semantic = true },
    { filetype = "vue", kind = 3, semantic = true },
    { filetype = "java", kind = 6, semantic = false },
    { filetype = "lua", kind = 15, semantic = false },
  }) do
    local plan = fixture.bracket_plan(case.filetype, "ca", nil, { label = "call", kind = case.kind })
    t.assert_eq("call", plan.main.newText, case.filetype)
    t.assert_eq(case.semantic, plan.semantic_brackets, case.filetype .. " semantic eligibility")
  end
  t.assert_eq("call()", fixture.bracket_plan("java", "ca", nil, { label = "call", kind = 3 }).main.newText)
end)

t:run()
