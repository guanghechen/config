local harness = require("__test__.support.harness")
local protocol = require("era.m.cmp.protocol")
local suite = harness.new("era.m.cmp.protocol")

suite:test("retains an immutable transport payload without deep copying it", function()
  local raw = { label = "alpha", data = { nested = { id = 1 } } }
  local item, err = protocol.prepare(raw, nil)
  suite.assert_nil(err, "preparation error")
  suite.assert_true(item == raw, "payload identity")
  suite.assert_nil(raw._era_cmp_source_context, "transport payload metadata")
end)

suite:test("applies defaults without mutating the item or replacing explicit falsy data", function()
  local raw = { label = "alpha", data = false }
  local defaults = {
    data = { id = 1 },
    insertTextFormat = 2,
    commitCharacters = { "." },
    editRange = { start = { line = 0, character = 0 }, ["end"] = { line = 0, character = 2 } },
  }
  local item, err = protocol.prepare(raw, defaults)
  suite.assert_nil(err, "preparation error")
  suite.assert_false(item.data, "explicit data")
  suite.assert_eq(2, item.insertTextFormat, "snippet default")
  suite.assert_eq(".", item.commitCharacters[1], "commit character default")
  suite.assert_eq("alpha", item.textEdit.newText, "default edit text")
  suite.assert_nil(raw.textEdit, "transport edit is unchanged")
  suite.assert_nil(raw.insertTextFormat, "transport format is unchanged")
end)

suite:test("an explicit edit takes precedence over a completion-list edit range", function()
  local edit =
    { newText = "alpha", range = { start = { line = 0, character = 0 }, ["end"] = { line = 0, character = 2 } } }
  local raw = { label = "alpha", textEdit = edit }
  local item = assert(protocol.prepare(raw, {
    editRange = { start = { line = 0, character = 0 }, ["end"] = { line = 0, character = 6 } },
  }))
  suite.assert_true(item.textEdit == edit, "explicit edit remains readonly")
  suite.assert_eq(2, raw.textEdit.range["end"].character, "transport edit boundary")
end)

suite:test("prefix completion uses the insert range instead of the replace range", function()
  local context =
    { bufnr = 1, row = 0, col = 2, line = "alTail", filetype = "lua", start_col = 0, end_col = 6, keyword = "al" }
  local item = {
    label = "alpha",
    textEdit = {
      newText = "alpha",
      insert = { start = { line = 0, character = 0 }, ["end"] = { line = 0, character = 2 } },
      replace = { start = { line = 0, character = 0 }, ["end"] = { line = 0, character = 6 } },
    },
  }
  suite.assert_eq(0, protocol.suffix_bytes(item, context, "utf-8"), "insert suffix")
  item.textEdit = { newText = "alpha", range = item.textEdit.replace }
  suite.assert_eq(4, protocol.suffix_bytes(item, context, "utf-8"), "explicit replacement suffix")
  item.textEdit = nil
  suite.assert_eq(0, protocol.suffix_bytes(item, context, "utf-8"), "inferred prefix preserves the keyword suffix")
end)

suite:test("invalid transport fields fail at the ingress boundary", function()
  local item, err = protocol.prepare({ label = "alpha", textEdit = { newText = false } }, nil)
  suite.assert_nil(item, "invalid item")
  suite.assert_true(type(err) == "string", "validation diagnostic")
  suite.assert_nil(protocol.prepare(false, nil), "non-table item")
  suite.assert_nil(protocol.prepare({ label = "alpha" }, false), "non-table defaults")
end)

suite:run()
