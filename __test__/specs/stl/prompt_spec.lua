local bootstrap = require("__test__.support.bootstrap")
local harness = require("__test__.support.harness")

local t = harness.new()

bootstrap.with_runtime(t, {
  stl = { env = { IS_TMUX = false } },
})

local prompt = require("stl.prompt")

t:test("tmux window resolver: executes tmux with argv", function()
  t:patch_table(stl.env, "IS_TMUX", true)

  local command = {} ---@type string[]
  t:patch_table(vim.fn, "system", function(cmd)
    command = cmd
    return "@7\n"
  end)

  local template = vim.iter(prompt.templates):find(function(item)
    return item.name == "review-design"
  end)
  t.assert_true(template ~= nil, "review-design template")

  local resolver = template.args.__TMUX_WINDOW_ID__ ---@type fun(): string
  local window_id, extra = resolver()
  t.assert_eq("@7", window_id, "window id")
  t.assert_nil(extra, "extra return value")
  t.assert_eq("tmux", command[1], "executable")
  t.assert_eq("display-message", command[2], "command")
  t.assert_eq("-p", command[3], "print flag")
  t.assert_eq("#{window_id}", command[4], "format")
end)

t:test("tmux window resolver: spawn failure degrades to an empty value", function()
  t:patch_table(stl.env, "IS_TMUX", true)
  t:patch_table(vim.fn, "system", function()
    error("spawn failed")
  end)

  local template = vim.iter(prompt.templates):find(function(item)
    return item.name == "review-design"
  end)
  t.assert_true(template ~= nil, "review-design template")

  local resolver = template.args.__TMUX_WINDOW_ID__ ---@type fun(): string
  t.assert_eq("", resolver(), "window id")
end)

for _, case in ipairs({
  { name = "substitute: empty string returns empty", input = "", expected = "" },
  { name = "substitute: text without variables unchanged", input = "hello world", expected = "hello world" },
  {
    name = "substitute: simple variable assignment and reference",
    input = [[
__FILE__=main.lua
Open ${__FILE__}
]],
    expected = "Open main.lua",
  },
  {
    name = "substitute: quoted value with spaces",
    input = [[
__MSG__="hello world"
Say: ${__MSG__}
]],
    expected = "Say: hello world",
  },
  {
    name = "substitute: multiple variables",
    input = [[
__A__=first
__B__=second
${__A__} and ${__B__}
]],
    expected = "first and second",
  },
  {
    name = "substitute: undefined variable kept as-is",
    input = [[
__DEFINED__=value
${__DEFINED__} and ${__UNDEFINED__}
]],
    expected = "value and ${__UNDEFINED__}",
  },
  {
    name = "substitute: assignment line removed from output",
    input = [[
__VAR__=test
line1
line2
]],
    expected = "line1\nline2",
  },
  {
    name = "substitute: multiple references to same variable",
    input = [[
__X__=foo
${__X__}${__X__}${__X__}
]],
    expected = "foofoofoo",
  },
  {
    name = "substitute: variable with underscores in name",
    input = [[
__FILE_PATH__=src/main.lua
__SELECTION_TEXT__="some code"
File: ${__FILE_PATH__}, Code: ${__SELECTION_TEXT__}
]],
    expected = "File: src/main.lua, Code: some code",
  },
  {
    name = "substitute: trims leading and trailing whitespace",
    input = [[

__VAR__=test

  result: ${__VAR__}

]],
    expected = "result: test",
  },
  {
    name = "substitute: assignment with empty value",
    input = [[
__EMPTY__=
Value is [${__EMPTY__}]
]],
    expected = "Value is []",
  },
  {
    name = "substitute: quoted empty value",
    input = [[
__EMPTY__=""
Value is [${__EMPTY__}]
]],
    expected = "Value is []",
  },
  {
    name = "substitute: value with equals sign",
    input = [[
__EQ__=a=b=c
Result: ${__EQ__}
]],
    expected = "Result: a=b=c",
  },
  {
    name = "substitute: preserves non-variable dollar signs",
    input = [[
__VAR__=test
Price is $100 and ${__VAR__}
]],
    expected = "Price is $100 and test",
  },
  {
    -- Only ${__VAR__} matches, others are not valid patterns
    name = "substitute: preserves incomplete patterns",
    input = [[
__VAR__=x
${__VAR__} and ${ __VAR__ } and ${__var__}
]],
    expected = "x and ${ __VAR__ } and ${__var__}",
  },
  { name = "substitute: inline reference without newline", input = "__X__=y\n${__X__}", expected = "y" },
  {
    name = "substitute: multiline content preserved",
    input = [[
__HEADER__=Title
${__HEADER__}
line1
line2
line3
]],
    expected = "Title\nline1\nline2\nline3",
  },
  {
    -- Line with leading spaces is not an assignment
    name = "substitute: assignment must be at line start",
    input = [[
  __VAR__=test
${__VAR__}
]],
    expected = "__VAR__=test\n${__VAR__}",
  },
  {
    name = "substitute: complex real-world example",
    input = [[
__FILE_PATH__=lua/era/m/ai/prompt.lua
__SELECTION_RANGE__="L10:C1-L20:C40"

Fix the diagnostics in @${__FILE_PATH__} ${__SELECTION_RANGE__}:
[ERROR] Line 15: unused variable 'x'
[WARN] Line 18: deprecated function
]],
    expected = "Fix the diagnostics in @lua/era/m/ai/prompt.lua L10:C1-L20:C40:\n[ERROR] Line 15: unused variable 'x'\n[WARN] Line 18: deprecated function",
  },
}) do
  t:test(case.name, function()
    t.assert_eq(case.expected, prompt.substitute(case.input))
  end)
end

-- Agents other than Codex receive slash commands as written.
for _, case in ipairs({
  { name = "render: claude keeps slash commands unchanged", agent = "claude", input = "/commit then /review" },
  { name = "render: gemini keeps slash commands unchanged", agent = "gemini", input = "/fix-code and /explain" },
  { name = "render: opencode keeps slash commands unchanged", agent = "opencode", input = "/test" },
  { name = "render: claude preserves all commands (no transformation)", agent = "claude", input = "/commit and /help" },
  { name = "render: gemini preserves all commands (no transformation)", agent = "gemini", input = "/chat and /custom" },
  {
    name = "render: opencode preserves all commands (no transformation)",
    agent = "opencode",
    input = "/init and /custom",
  },
}) do
  t:test(case.name, function()
    t.assert_eq(case.input, prompt.render(case.input, case.agent))
  end)
end

-- Codex runs a custom prompt as /prompts:<name> and keeps its builtin commands.
for _, case in ipairs({
  { name = "render: codex transforms hyphenated commands", input = "/fix-code", expected = "/prompts:fix-code" },
  {
    name = "render: codex transforms multiple commands",
    input = "/commit and then /review-pr",
    expected = "/prompts:commit and then /prompts:review-pr",
  },
  {
    -- These should NOT be treated as slash commands (contain /)
    name = "render: preserves path-like strings",
    input = "Check /usr/local/bin and /etc/config",
    expected = "Check /usr/local/bin and /etc/config",
  },
  {
    name = "render: handles command at start of line",
    input = "/commit\n/review",
    expected = "/prompts:commit\n/prompts:review",
  },
  {
    name = "render: preserves non-command slashes",
    input = "a/b and /command",
    expected = "a/b and /prompts:command",
  },
  { name = "render: codex preserves builtin /help", input = "/help", expected = "/help" },
  { name = "render: codex preserves builtin /clear", input = "/clear", expected = "/clear" },
  { name = "render: codex transforms non-builtin /commit", input = "/commit", expected = "/prompts:commit" },
  {
    name = "render: codex mixed builtin and non-builtin",
    input = "/help then /commit and /model",
    expected = "/help then /prompts:commit and /model",
  },
}) do
  t:test(case.name, function()
    t.assert_eq(case.expected, prompt.render(case.input, "codex"))
  end)
end

t:test("render: combines variable substitution with slash transform", function()
  local input = [[
__FILE__=main.lua
/fix ${__FILE__}
]]
  t.assert_eq("/fix main.lua", prompt.render(input, "claude"))
  t.assert_eq("/prompts:fix main.lua", prompt.render(input, "codex"))
end)

t:run()
