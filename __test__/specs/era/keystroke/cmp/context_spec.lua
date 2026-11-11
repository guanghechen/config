local harness = require("__test__.support.harness")
local runtime = require("__test__.support.cmp.runtime")
local fixture = require("__test__.support.cmp.fixture")
local t = harness.new()
local Context = require("era.keystroke.cmp.context")

t:test("the word before the cursor on a long line is found fast and right", function()
  local line = "![img](data:image/png;base64," .. fixture.base64(100 * 1024) .. ") word"
  t.assert_eq(#line - 4, Context.start_col(line, #line), "start of the word")
  t.assert_eq(4, Context.start_col("x = abc", 7), "a short line afterwards")
end)

t:test("different directory prefixes and buffer revisions invalidate caches", function()
  t.assert_true(Context.extends(runtime.context("@lua/era/"), runtime.context("@lua/era/p")), "basename continuation")
  t.assert_eq(false, Context.extends(runtime.context("@lua/era/p"), runtime.context("@lua/e")), "directory changed")
  local current = runtime.context("foobar")
  current.buffer_version = 1
  t.assert_eq(false, Context.extends(runtime.context("foo"), current), "external buffer edit")
end)

t:run()
