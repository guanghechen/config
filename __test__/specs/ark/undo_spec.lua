local harness = require("__test__.support.harness")
local undo = require("__test__.support.undo")
local t = harness.new()

require("ark.keymap")

t:test("ASCII punctuation ends an undo step", function()
  t.assert_same({
    { "one,two.three;four" },
    { "one,two.three;" },
    { "one,two." },
    { "one," },
    { "" },
  }, undo.states(t, "one,two.three;four"))
end)

t:test("full-width punctuation from an input method ends an undo step too", function()
  t.assert_same({
    { "你好，世界。天气不错；注意：真好！对吗？再见" },
    { "你好，世界。天气不错；注意：真好！对吗？" },
    { "你好，世界。天气不错；注意：真好！" },
    { "你好，世界。天气不错；注意：" },
    { "你好，世界。天气不错；" },
    { "你好，世界。" },
    { "你好，" },
    { "" },
  }, undo.states(t, "你好，世界。天气不错；注意：真好！对吗？再见"))
end)

t:test("undo takes back a word with the space before it, as in VS Code", function()
  t.assert_same({
    { "the quick  brown fox" },
    { "the quick  brown" },
    { "the quick" },
    { "the" },
    { "" },
  }, undo.states(t, "the quick  brown fox"))
end)

t:test("undo takes back a line with its line break", function()
  t.assert_same({
    { "one", "two", "three" },
    { "one", "two" },
    { "one" },
    { "" },
  }, undo.states(t, "one<CR>two<CR>three"))
end)

t:run()
