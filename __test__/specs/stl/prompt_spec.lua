--- Run with: nvim -l __test__/run.lua __test__/specs/stl/prompt_spec.lua
---@diagnostic disable: undefined-global
--- Test for stl.prompt module

local bootstrap = require("__test__.support.bootstrap")
local harness = require("__test__.support.harness")

local t = harness.new("stl.prompt")

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

----------------------------------------------------------------------------------------------------
-- substitute tests
----------------------------------------------------------------------------------------------------

t:test("substitute: empty string returns empty", function()
  t.assert_eq("", prompt.substitute(""))
end)

t:test("substitute: text without variables unchanged", function()
  t.assert_eq("hello world", prompt.substitute("hello world"))
end)

t:test("substitute: simple variable assignment and reference", function()
  local input = [[
__FILE__=main.lua
Open ${__FILE__}
]]
  t.assert_eq("Open main.lua", prompt.substitute(input))
end)

t:test("substitute: quoted value with spaces", function()
  local input = [[
__MSG__="hello world"
Say: ${__MSG__}
]]
  t.assert_eq("Say: hello world", prompt.substitute(input))
end)

t:test("substitute: multiple variables", function()
  local input = [[
__A__=first
__B__=second
${__A__} and ${__B__}
]]
  t.assert_eq("first and second", prompt.substitute(input))
end)

t:test("substitute: undefined variable kept as-is", function()
  local input = [[
__DEFINED__=value
${__DEFINED__} and ${__UNDEFINED__}
]]
  t.assert_eq("value and ${__UNDEFINED__}", prompt.substitute(input))
end)

t:test("substitute: assignment line removed from output", function()
  local input = [[
__VAR__=test
line1
line2
]]
  t.assert_eq("line1\nline2", prompt.substitute(input))
end)

t:test("substitute: multiple references to same variable", function()
  local input = [[
__X__=foo
${__X__}${__X__}${__X__}
]]
  t.assert_eq("foofoofoo", prompt.substitute(input))
end)

t:test("substitute: variable with underscores in name", function()
  local input = [[
__FILE_PATH__=src/main.lua
__SELECTION_TEXT__="some code"
File: ${__FILE_PATH__}, Code: ${__SELECTION_TEXT__}
]]
  t.assert_eq("File: src/main.lua, Code: some code", prompt.substitute(input))
end)

t:test("substitute: trims leading and trailing whitespace", function()
  local input = [[

__VAR__=test

  result: ${__VAR__}

]]
  t.assert_eq("result: test", prompt.substitute(input))
end)

t:test("substitute: assignment with empty value", function()
  local input = [[
__EMPTY__=
Value is [${__EMPTY__}]
]]
  t.assert_eq("Value is []", prompt.substitute(input))
end)

t:test("substitute: quoted empty value", function()
  local input = [[
__EMPTY__=""
Value is [${__EMPTY__}]
]]
  t.assert_eq("Value is []", prompt.substitute(input))
end)

t:test("substitute: value with equals sign", function()
  local input = [[
__EQ__=a=b=c
Result: ${__EQ__}
]]
  t.assert_eq("Result: a=b=c", prompt.substitute(input))
end)

t:test("substitute: preserves non-variable dollar signs", function()
  local input = [[
__VAR__=test
Price is $100 and ${__VAR__}
]]
  t.assert_eq("Price is $100 and test", prompt.substitute(input))
end)

t:test("substitute: preserves incomplete patterns", function()
  local input = [[
__VAR__=x
${__VAR__} and ${ __VAR__ } and ${__var__}
]]
  -- Only ${__VAR__} matches, others are not valid patterns
  t.assert_eq("x and ${ __VAR__ } and ${__var__}", prompt.substitute(input))
end)

t:test("substitute: inline reference without newline", function()
  local input = "__X__=y\n${__X__}"
  t.assert_eq("y", prompt.substitute(input))
end)

t:test("substitute: multiline content preserved", function()
  local input = [[
__HEADER__=Title
${__HEADER__}
line1
line2
line3
]]
  t.assert_eq("Title\nline1\nline2\nline3", prompt.substitute(input))
end)

t:test("substitute: assignment must be at line start", function()
  local input = [[
  __VAR__=test
${__VAR__}
]]
  -- Line with leading spaces is not an assignment
  t.assert_eq("__VAR__=test\n${__VAR__}", prompt.substitute(input))
end)

t:test("substitute: complex real-world example", function()
  local input = [[
__FILE_PATH__=lua/era/m/ai/prompt.lua
__SELECTION_RANGE__="L10:C1-L20:C40"

Fix the diagnostics in @${__FILE_PATH__} ${__SELECTION_RANGE__}:
[ERROR] Line 15: unused variable 'x'
[WARN] Line 18: deprecated function
]]
  local expected =
    "Fix the diagnostics in @lua/era/m/ai/prompt.lua L10:C1-L20:C40:\n[ERROR] Line 15: unused variable 'x'\n[WARN] Line 18: deprecated function"
  t.assert_eq(expected, prompt.substitute(input))
end)

----------------------------------------------------------------------------------------------------
-- render tests
----------------------------------------------------------------------------------------------------

t:test("render: claude keeps slash commands unchanged", function()
  local input = "/commit then /review"
  t.assert_eq("/commit then /review", prompt.render(input, "claude"))
end)

t:test("render: gemini keeps slash commands unchanged", function()
  local input = "/fix-code and /explain"
  t.assert_eq("/fix-code and /explain", prompt.render(input, "gemini"))
end)

t:test("render: opencode keeps slash commands unchanged", function()
  local input = "/test"
  t.assert_eq("/test", prompt.render(input, "opencode"))
end)

t:test("render: codex transforms slash commands", function()
  local input = "/commit"
  t.assert_eq("/prompts:commit", prompt.render(input, "codex"))
end)

t:test("render: codex transforms hyphenated commands", function()
  local input = "/fix-code"
  t.assert_eq("/prompts:fix-code", prompt.render(input, "codex"))
end)

t:test("render: codex transforms multiple commands", function()
  local input = "/commit and then /review-pr"
  t.assert_eq("/prompts:commit and then /prompts:review-pr", prompt.render(input, "codex"))
end)

t:test("render: combines variable substitution with slash transform", function()
  local input = [[
__FILE__=main.lua
/fix ${__FILE__}
]]
  t.assert_eq("/fix main.lua", prompt.render(input, "claude"))
  t.assert_eq("/prompts:fix main.lua", prompt.render(input, "codex"))
end)

t:test("render: preserves path-like strings", function()
  local input = "Check /usr/local/bin and /etc/config"
  -- These should NOT be treated as slash commands (contain /)
  t.assert_eq("Check /usr/local/bin and /etc/config", prompt.render(input, "codex"))
end)

t:test("render: handles command at start of line", function()
  local input = "/commit\n/review"
  t.assert_eq("/prompts:commit\n/prompts:review", prompt.render(input, "codex"))
end)

t:test("render: preserves non-command slashes", function()
  local input = "a/b and /command"
  t.assert_eq("a/b and /prompts:command", prompt.render(input, "codex"))
end)

----------------------------------------------------------------------------------------------------
-- builtin command tests
----------------------------------------------------------------------------------------------------

t:test("render: codex preserves builtin /help", function()
  local input = "/help"
  t.assert_eq("/help", prompt.render(input, "codex"))
end)

t:test("render: codex preserves builtin /clear", function()
  local input = "/clear"
  t.assert_eq("/clear", prompt.render(input, "codex"))
end)

t:test("render: codex transforms non-builtin /commit", function()
  local input = "/commit"
  t.assert_eq("/prompts:commit", prompt.render(input, "codex"))
end)

t:test("render: codex mixed builtin and non-builtin", function()
  local input = "/help then /commit and /model"
  t.assert_eq("/help then /prompts:commit and /model", prompt.render(input, "codex"))
end)

t:test("render: claude preserves all commands (no transformation)", function()
  local input = "/commit and /help"
  t.assert_eq("/commit and /help", prompt.render(input, "claude"))
end)

t:test("render: gemini preserves all commands (no transformation)", function()
  local input = "/chat and /custom"
  t.assert_eq("/chat and /custom", prompt.render(input, "gemini"))
end)

t:test("render: opencode preserves all commands (no transformation)", function()
  local input = "/init and /custom"
  t.assert_eq("/init and /custom", prompt.render(input, "opencode"))
end)

t:run()
