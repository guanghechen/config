local harness = require("__test__.support.harness")
local runtime = require("__test__.support.cmp.runtime")
local fixture = require("__test__.support.cmp.fixture")
runtime.setup()
local t = harness.new()
local Item = require("era.keystroke.cmp.item")
local Edit = require("era.keystroke.cmp.edit")

t:test("applying completion preserves an unlisted source buffer", function()
  local bufnr = t:buffer({ "al" }, { scratch = false, current = true })
  local context = runtime.context("al")
  t:patch_table(require("era.keystroke.cmp.context"), "capture", function()
    return context
  end)
  local item = assert(Item.new(context, "lsp", { label = "alpha" }))
  t.assert_true(Edit.apply(context, assert(Edit.plan(item, context))))
  t.assert_eq("alpha", vim.api.nvim_get_current_line())
  t.assert_false(vim.api.nvim_get_option_value("buflisted", { buf = bufnr }))
end)

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
  local bufnr = t:buffer({ "al" }, { listed = true, current = true })
  vim.api.nvim_set_option_value("endofline", true, { buf = bufnr })
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
  t.assert_same({ "alpha", "-- trailing declaration" }, vim.api.nvim_buf_get_lines(bufnr, 0, -1, false))
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
  local plan = fixture.bracket_plan("lua", "ca()", 2, raw)
  t.assert_eq(false, plan.snippet, "plain function name")
  t.assert_eq(false, plan.create_undo_point, "original snippet format retains its undo boundary")
  t.assert_eq("call", plan.main.newText, "existing brackets preserved")
  t.assert_eq(1, plan.cursor_offset, "cursor enters existing brackets")
  plan = fixture.bracket_plan("lua", "ca", nil, raw)
  t.assert_eq("call()", plan.main.newText, "no artificial snippet tabstop")
  t.assert_eq(-1, plan.cursor_offset, "cursor enters generated brackets")

  plan = fixture.bracket_plan("lua", "ca", nil, { label = "call", kind = 6, insertTextFormat = 2, insertText = "\\$1" })
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

t:run()
