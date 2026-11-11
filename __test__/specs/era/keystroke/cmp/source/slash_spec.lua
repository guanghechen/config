local harness = require("__test__.support.harness")
local runtime = require("__test__.support.cmp.runtime")
runtime.setup()
local t = harness.new()

t:test("slash commands continue across hyphens and carry their own edit range", function()
  local response
  require("era.keystroke.cmp.source.slash").complete(runtime.context("请 /code-an"), function(value)
    response = value
  end)
  t.assert_true(#response.items > 0, "slash commands")
  t.assert_eq(#"请 ", response.items[1].start_col, "byte edit start")
  t.assert_eq("/code-analyze ", response.items[1].raw.textEdit.newText, "insert command")
end)

t:run()
