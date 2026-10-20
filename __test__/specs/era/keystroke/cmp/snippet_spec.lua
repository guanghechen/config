local harness = require("__test__.support.harness")
local t = harness.new()
local Snippet = require("era.keystroke.cmp.snippet")

t:test("preview words preserve literal prefixes and omit arguments and snippet syntax", function()
  for _, example in ipairs({
    { "normalize(${1:value})$0", "normalize(value)", "normalize" },
    { "function ${1:name}(${2:args})\n\t$0\nend", "fn", "function" },
    { "${1:normalize}(${2:value})$0", "fn", "normalize" },
    { "${1|alpha,beta|}(${2:value})$0", "choice", "alpha" },
    { "取值(${1:参数})$0", "取值(参数)", "取值" },
    { "<div>${1:body}</div>$0", "div", "<div>" },
    { "['name'] = ${1:value}", "name", "['name']" },
    { "'name' = ${1:value}", "name", "'name'" },
    { "  call(${1:value})", "call(value)", "  call" },
    { "path\\\\name$0", "path", "path\\name" },
    { "\\$normalize(${1:value})$0", "$normalize(value)", "$normalize" },
    { "$0", "empty", "" },
  }) do
    t.assert_eq(example[3], Snippet.preview_word(example[1], example[2]), example[1])
  end
end)

t:test("preview words stop before variables without reading dynamic input", function()
  t:patch_table(vim.fn, "getreg", function()
    error("preview must not read registers")
  end)
  t:patch_table(math, "random", function()
    error("preview must not evaluate random variables")
  end)
  for _, example in ipairs({
    { "${RANDOM}:${1:name}$0", "random", "random" },
    { "${1:${CLIPBOARD}}suffix", "paste", "paste" },
    { "  ${CLIPBOARD}", "paste", "paste" },
    { "prefix${TM_FILENAME_BASE}suffix", "file", "prefix" },
    { "call(${CURRENT_YEAR})$0", "call(year)", "call" },
    { "${broken", "fallback(value)", "fallback" },
  }) do
    t.assert_eq(example[3], Snippet.preview_word(example[1], example[2]), example[1])
  end
end)

t:run()
