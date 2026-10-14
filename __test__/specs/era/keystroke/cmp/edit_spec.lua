local harness = require("__test__.support.harness")
local runtime = require("__test__.fixtures.era.keystroke.cmp.runtime")
runtime.setup()
local t = harness.new("era.keystroke.cmp.edit")
local Item = require("era.keystroke.cmp.item")
local Edit = require("era.keystroke.cmp.edit")
local Brackets = require("era.keystroke.cmp.brackets")

t:test("applying completion preserves an unlisted source buffer", function()
  local previous = vim.api.nvim_get_current_buf()
  local bufnr = vim.api.nvim_create_buf(false, false)
  t:defer(function()
    vim.api.nvim_set_current_buf(previous)
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end)
  vim.api.nvim_set_current_buf(bufnr)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "al" })
  local context = runtime.context("al")
  t:patch_table(require("era.keystroke.cmp.context"), "capture", function()
    return context
  end)
  local item = assert(Item.new(context, "lsp", { label = "alpha" }))
  t.assert_true(Edit.apply(context, assert(Edit.plan(item, context))))
  t.assert_eq("alpha", vim.api.nvim_get_current_line())
  t.assert_false(vim.api.nvim_get_option_value("buflisted", { buf = bufnr }))
end)

---@param filetype                      string
---@param line                          string
---@param col                           ?integer
---@param raw                           lsp.CompletionItem
---@return era.keystroke.cmp.IEditPlan
local function bracket_plan(filetype, line, col, raw)
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { line })
  local context = runtime.context(line, col)
  context.filetype = filetype
  local plan = assert(Edit.plan(assert(Item.new(context, "lsp", raw)), context))
  Brackets.prepare(context, raw, plan)
  return plan
end

t:test("UTF-16 main and additional edits rebase over typed UTF-8 text", function()
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "-- import here", "😀 fo tail" })
  local origin = runtime.context("😀 fo tail", #"😀 fo", 1)
  local raw = {
    label = "foobar",
    textEdit = {
      newText = "foobar",
      range = { start = { line = 1, character = 3 }, ["end"] = { line = 1, character = 5 } },
    },
    additionalTextEdits = {
      {
        newText = "local foo = require('foo')\n",
        range = { start = { line = 0, character = 0 }, ["end"] = { line = 0, character = 0 } },
      },
      { newText = "after", range = { start = { line = 1, character = 6 }, ["end"] = { line = 1, character = 10 } } },
    },
  }
  local item = assert(Item.new(origin, "lsp", raw, { id = 1, offset_encoding = "utf-16" }))
  local current = runtime.context("😀 foo tail", #"😀 foo", 1)
  local plan = assert(Edit.plan(item, current))
  t.assert_eq(#"😀 ", plan.main.range.start.character, "byte start")
  t.assert_eq(#"😀 foo", plan.main.range["end"].character, "rebased byte end")
  t.assert_eq(#"😀 foo ", plan.additional[2].range.start.character, "additional edit after cursor")
  t.assert_eq(0, plan.additional[1].range.start.character, "import position")
end)

t:test("empty completion range retains its anchor as the user types", function()
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "obj." })
  local context = runtime.context("obj.")
  local raw = { label = "method", textEdit = Item.text_edit(context, 4, "method") }
  local item = assert(Item.new(context, "lsp", raw))
  local plan = assert(Edit.plan(item, runtime.context("obj.me")))
  t.assert_eq(4, plan.main.range.start.character, "original anchor")
  t.assert_eq(6, plan.main.range["end"].character, "current end")
end)

t:test("InsertReplaceEdit follows prefix insertion and preserves the suffix", function()
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "foSuffix" })
  local context = runtime.context("foSuffix", 2)
  local item = assert(Item.new(context, "lsp", {
    label = "foo",
    textEdit = {
      newText = "foo",
      insert = { start = { line = 0, character = 0 }, ["end"] = { line = 0, character = 2 } },
      replace = { start = { line = 0, character = 0 }, ["end"] = { line = 0, character = 8 } },
    },
  }))
  local plan = assert(Edit.plan(item, context))
  t.assert_eq(2, plan.main.range["end"].character, "insert range")
end)

t:test("overlapping edits and unrelated input are rejected before mutation", function()
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "foo" })
  local context = runtime.context("foo")
  local item =
    assert(Item.new(context, "lsp", { label = "foobar", additionalTextEdits = { Item.text_edit(context, 1, "x") } }))
  t.assert_eq(nil, Edit.plan(item, context), "overlap")
  local plain = assert(Item.new(context, "buffer", { label = "foobar" }))
  t.assert_eq(nil, Edit.plan(plain, runtime.context("obj.foo")), "different prefix")
  t.assert_eq("foo", vim.api.nvim_get_current_line(), "input preserved")
end)

t:test("missing or null required edit text cannot use a fallback insertion", function()
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "al" })
  local context = runtime.context("al")
  local range = Item.text_edit(context, 0, "alpha").range
  for _, edit in ipairs({ { range = range }, { range = range, newText = vim.NIL } }) do
    local item = assert(Item.new(context, "lsp", {
      label = "alpha",
      insertText = "unrelated fallback",
      textEdit = edit,
    }))
    t.assert_nil(Edit.plan(item, context), "required newText is validated before editing")
  end
  t.assert_eq("al", vim.api.nvim_get_current_line(), "buffer remains unchanged")
end)

t:test("range boundaries allow insertions and reject interior overlaps", function()
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "fo tail" })
  local context = runtime.context("fo tail", 2)
  for _, case in ipairs({
    { ranges = { { 0, 0 } }, valid = true },
    { ranges = { { 2, 2 } }, valid = true },
    { ranges = { { 2, 2 }, { 0, 0 } }, valid = true },
    { ranges = { { 2, 7 } }, valid = true },
    { ranges = { { 1, 1 } }, valid = false },
    { ranges = { { 0, 1 } }, valid = false },
    { ranges = { { 1, 3 } }, valid = false },
    { ranges = { { 0, 7 } }, valid = false },
    { ranges = { { 3, 5 }, { 4, 6 } }, valid = false },
    { ranges = { { 3, 5 }, { 4, 4 } }, valid = false },
  }) do
    local additional = {}
    for _, range in ipairs(case.ranges) do
      additional[#additional + 1] = {
        newText = "inserted",
        range = { start = { line = 0, character = range[1] }, ["end"] = { line = 0, character = range[2] } },
      }
    end
    local item = assert(Item.new(context, "lsp", {
      label = "foobar",
      textEdit = Item.text_edit(context, 0, "foobar"),
      additionalTextEdits = additional,
    }))
    t.assert_eq(case.valid, Edit.plan(item, context) ~= nil, vim.inspect(case.ranges))
  end
  t.assert_eq("fo tail", vim.api.nvim_get_current_line(), "validation does not mutate the buffer")
end)

t:test("additional edits can append at the document's final newline", function()
  local previous = vim.api.nvim_get_current_buf()
  local bufnr = vim.api.nvim_create_buf(true, false)
  t:defer(function()
    vim.api.nvim_set_current_buf(previous)
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end)
  vim.api.nvim_set_current_buf(bufnr)
  vim.api.nvim_set_option_value("endofline", true, { buf = bufnr })
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "al" })
  local context = runtime.context("al")
  local item = assert(Item.new(context, "lsp", {
    label = "alpha",
    additionalTextEdits = {
      {
        newText = "-- trailing declaration\n",
        range = { start = { line = 1, character = 0 }, ["end"] = { line = 1, character = 0 } },
      },
    },
  }, { id = 1, offset_encoding = "utf-16" }))
  t:patch_table(require("era.keystroke.cmp.context"), "capture", function()
    return context
  end)
  local plan = assert(Edit.plan(item, context), "the final newline exposes an empty EOF line to LSP")
  t.assert_true(Edit.apply(context, plan))
  t.assert_true(vim.deep_equal({ "alpha", "-- trailing declaration" }, vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)))
end)

t:test("additional edits outside the document are rejected before mutation", function()
  local previous = vim.api.nvim_get_option_value("endofline", { buf = 0 })
  t:defer(function()
    vim.api.nvim_set_option_value("endofline", previous, { buf = 0 })
  end)
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "al" })
  local context = runtime.context("al")
  for _, example in ipairs({
    { eol = true, line = 1, character = 1 },
    { eol = true, line = 2, character = 0 },
    { eol = false, line = 1, character = 0 },
  }) do
    vim.api.nvim_set_option_value("endofline", example.eol, { buf = 0 })
    local position = { line = example.line, character = example.character }
    local item = assert(Item.new(context, "lsp", {
      label = "alpha",
      additionalTextEdits = { { newText = "invalid", range = { start = position, ["end"] = position } } },
    }))
    t.assert_nil(Edit.plan(item, context), vim.inspect(example))
  end
  t.assert_eq("al", vim.api.nvim_get_current_line(), "failed validation leaves the input unchanged")
end)

t:test("snippet preview and acceptance share the native snippet syntax", function()
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "fn" })
  local context = runtime.context("fn")
  local raw = { label = "function", insertTextFormat = 2, insertText = "function ${1:name}($0)" }
  local item = assert(Item.new(context, "snippets", raw))
  t.assert_true(assert(Edit.plan(item, context)).snippet, "snippet plan")
  t.assert_eq("function name()", Edit.snippet_text(raw.insertText), "preview text")
end)

t:test("snippet final stops and placeholder conflicts are rejected before edits", function()
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "pre" })
  local context = runtime.context("pre")
  for _, body in ipairs({ "hello$0world$0", "${0:last}$0", "${0|one,two|}$0", "${1:a}${1:b}" }) do
    local item = assert(Item.new(context, "snippets", { label = "pre", insertTextFormat = 2, insertText = body }))
    t.assert_nil(Edit.plan(item, context), body)
  end
  t.assert_eq("$0hello", Edit.snippet_text("\\$0hello$0"), "escaped stops remain literal")
  t.assert_eq("pre", vim.api.nvim_get_current_line(), "input preserved")
end)

t:test("text-only snippet format uses plain acceptance and decodes escaped literals", function()
  local raw = { label = "call", kind = 3, insertTextFormat = 2, insertText = "call" }
  local plan = bracket_plan("lua", "ca()", 2, raw)
  t.assert_eq(false, plan.snippet, "plain function name")
  t.assert_eq(false, plan.create_undo_point, "original snippet format retains its undo boundary")
  t.assert_eq("call", plan.main.newText, "existing brackets preserved")
  t.assert_eq(1, plan.cursor_offset, "cursor enters existing brackets")
  plan = bracket_plan("lua", "ca", nil, raw)
  t.assert_eq("call()", plan.main.newText, "no artificial snippet tabstop")
  t.assert_eq(-1, plan.cursor_offset, "cursor enters generated brackets")

  plan = bracket_plan("lua", "ca", nil, { label = "call", kind = 6, insertTextFormat = 2, insertText = "\\$1" })
  t.assert_eq(false, plan.snippet, "escaped tabstop is plain text")
  t.assert_eq("$1", plan.main.newText, "literal escape decoded once")
end)

t:test("real snippet nodes, explicit snippet items and multiline text retain snippet semantics", function()
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "ca" })
  local context = runtime.context("ca")
  for _, case in ipairs({
    { kind = 15, body = "call" },
    { kind = 3, body = "call$0" },
    { kind = 3, body = "call${1:Back}" },
    { kind = 3, body = "call\nnext" },
    { kind = 3, body = "${TM_FILENAME}" },
  }) do
    local item = assert(
      Item.new(context, "lsp", { label = "call", kind = case.kind, insertTextFormat = 2, insertText = case.body })
    )
    t.assert_true(assert(Edit.plan(item, context)).snippet, case.body)
  end
  local item =
    assert(Item.new(context, "lsp", { label = "call", kind = 3, insertTextFormat = 2, insertText = "${TM_FILENAME}" }))
  item.expansion = { body = "${TM_FILENAME}", text = "call", context = context }
  t.assert_true(assert(Edit.plan(item, context)).snippet, "expanded variable retains original snippet semantics")
end)

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
      local plan = bracket_plan(case.filetype, case.line, case.col, { label = case.label, kind = kind })
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
    local plan = bracket_plan(case.filetype, case.line, nil, { label = case.label, kind = 3 })
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
      local plan = bracket_plan(case.filetype, case.line, case.col, { label = case.label, kind = kind })
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
    local plan =
      bracket_plan(case.filetype, "ca", nil, { label = "call", kind = 3, insertTextFormat = 2, insertText = case.body })
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
    local plan = bracket_plan(case.filetype, "ca", nil, { label = "call", kind = case.kind })
    t.assert_eq("call", plan.main.newText, case.filetype)
    t.assert_eq(case.semantic, plan.semantic_brackets, case.filetype .. " semantic eligibility")
  end
  t.assert_eq("call()", bracket_plan("java", "ca", nil, { label = "call", kind = 3 }).main.newText)
end)

t:run()
