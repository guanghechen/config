---@diagnostic disable: undefined-global
--- Test for stl.prompt module
--- Run with: nvim -l lua/__test__/stl/prompt.lua

local prompt = require("stl.prompt")

local passed = 0
local failed = 0

---@param name                          string
---@param fn                            fun()
local function test(name, fn)
  local ok, err = pcall(fn)
  if ok then
    passed = passed + 1
    print("✓ " .. name)
  else
    failed = failed + 1
    print("✗ " .. name)
    print("  Error: " .. tostring(err))
  end
end

---@param expected                      any
---@param actual                        any
---@param msg                           ?string
local function assert_eq(expected, actual, msg)
  if expected ~= actual then
    error(string.format("%s: expected %q, got %q", msg or "assertion failed", tostring(expected), tostring(actual)))
  end
end

----------------------------------------------------------------------------------------------------
-- substitute tests
----------------------------------------------------------------------------------------------------

test("substitute: empty string returns empty", function()
  assert_eq("", prompt.substitute(""))
end)

test("substitute: text without variables unchanged", function()
  assert_eq("hello world", prompt.substitute("hello world"))
end)

test("substitute: simple variable assignment and reference", function()
  local input = [[
__FILE__=main.lua
Open ${__FILE__}
]]
  assert_eq("Open main.lua", prompt.substitute(input))
end)

test("substitute: quoted value with spaces", function()
  local input = [[
__MSG__="hello world"
Say: ${__MSG__}
]]
  assert_eq("Say: hello world", prompt.substitute(input))
end)

test("substitute: multiple variables", function()
  local input = [[
__A__=first
__B__=second
${__A__} and ${__B__}
]]
  assert_eq("first and second", prompt.substitute(input))
end)

test("substitute: undefined variable kept as-is", function()
  local input = [[
__DEFINED__=value
${__DEFINED__} and ${__UNDEFINED__}
]]
  assert_eq("value and ${__UNDEFINED__}", prompt.substitute(input))
end)

test("substitute: assignment line removed from output", function()
  local input = [[
__VAR__=test
line1
line2
]]
  assert_eq("line1\nline2", prompt.substitute(input))
end)

test("substitute: multiple references to same variable", function()
  local input = [[
__X__=foo
${__X__}${__X__}${__X__}
]]
  assert_eq("foofoofoo", prompt.substitute(input))
end)

test("substitute: variable with underscores in name", function()
  local input = [[
__FILE_PATH__=src/main.lua
__SELECTION_TEXT__="some code"
File: ${__FILE_PATH__}, Code: ${__SELECTION_TEXT__}
]]
  assert_eq("File: src/main.lua, Code: some code", prompt.substitute(input))
end)

test("substitute: trims leading and trailing whitespace", function()
  local input = [[

__VAR__=test

  result: ${__VAR__}

]]
  assert_eq("result: test", prompt.substitute(input))
end)

test("substitute: assignment with empty value", function()
  local input = [[
__EMPTY__=
Value is [${__EMPTY__}]
]]
  assert_eq("Value is []", prompt.substitute(input))
end)

test("substitute: quoted empty value", function()
  local input = [[
__EMPTY__=""
Value is [${__EMPTY__}]
]]
  assert_eq("Value is []", prompt.substitute(input))
end)

test("substitute: value with equals sign", function()
  local input = [[
__EQ__=a=b=c
Result: ${__EQ__}
]]
  assert_eq("Result: a=b=c", prompt.substitute(input))
end)

test("substitute: preserves non-variable dollar signs", function()
  local input = [[
__VAR__=test
Price is $100 and ${__VAR__}
]]
  assert_eq("Price is $100 and test", prompt.substitute(input))
end)

test("substitute: preserves incomplete patterns", function()
  local input = [[
__VAR__=x
${__VAR__} and ${ __VAR__ } and ${__var__}
]]
  -- Only ${__VAR__} matches, others are not valid patterns
  assert_eq("x and ${ __VAR__ } and ${__var__}", prompt.substitute(input))
end)

test("substitute: inline reference without newline", function()
  local input = "__X__=y\n${__X__}"
  assert_eq("y", prompt.substitute(input))
end)

test("substitute: multiline content preserved", function()
  local input = [[
__HEADER__=Title
${__HEADER__}
line1
line2
line3
]]
  assert_eq("Title\nline1\nline2\nline3", prompt.substitute(input))
end)

test("substitute: assignment must be at line start", function()
  local input = [[
  __VAR__=test
${__VAR__}
]]
  -- Line with leading spaces is not an assignment
  assert_eq("__VAR__=test\n${__VAR__}", prompt.substitute(input))
end)

test("substitute: complex real-world example", function()
  local input = [[
__FILE_PATH__=lua/era/m/ai/prompt.lua
__SELECTION_RANGE__="L10:C1-L20:C40"

Fix the diagnostics in @${__FILE_PATH__} ${__SELECTION_RANGE__}:
[ERROR] Line 15: unused variable 'x'
[WARN] Line 18: deprecated function
]]
  local expected =
    "Fix the diagnostics in @lua/era/m/ai/prompt.lua L10:C1-L20:C40:\n[ERROR] Line 15: unused variable 'x'\n[WARN] Line 18: deprecated function"
  assert_eq(expected, prompt.substitute(input))
end)

----------------------------------------------------------------------------------------------------
-- render tests
----------------------------------------------------------------------------------------------------

test("render: claude keeps slash commands unchanged", function()
  local input = "/commit then /review"
  assert_eq("/commit then /review", prompt.render(input, "claude"))
end)

test("render: gemini keeps slash commands unchanged", function()
  local input = "/fix-code and /explain"
  assert_eq("/fix-code and /explain", prompt.render(input, "gemini"))
end)

test("render: opencode keeps slash commands unchanged", function()
  local input = "/test"
  assert_eq("/test", prompt.render(input, "opencode"))
end)

test("render: copilot keeps slash commands unchanged", function()
  local input = "/help"
  assert_eq("/help", prompt.render(input, "copilot"))
end)

test("render: codex transforms slash commands", function()
  local input = "/commit"
  assert_eq("/prompts:commit", prompt.render(input, "codex"))
end)

test("render: codex transforms hyphenated commands", function()
  local input = "/fix-code"
  assert_eq("/prompts:fix-code", prompt.render(input, "codex"))
end)

test("render: codex transforms multiple commands", function()
  local input = "/commit and then /review-pr"
  assert_eq("/prompts:commit and then /prompts:review-pr", prompt.render(input, "codex"))
end)

test("render: combines variable substitution with slash transform", function()
  local input = [[
__FILE__=main.lua
/fix ${__FILE__}
]]
  assert_eq("/fix main.lua", prompt.render(input, "claude"))
  assert_eq("/prompts:fix main.lua", prompt.render(input, "codex"))
end)

test("render: preserves path-like strings", function()
  local input = "Check /usr/local/bin and /etc/config"
  -- These should NOT be treated as slash commands (contain /)
  assert_eq("Check /usr/local/bin and /etc/config", prompt.render(input, "codex"))
end)

test("render: handles command at start of line", function()
  local input = "/commit\n/review"
  assert_eq("/prompts:commit\n/prompts:review", prompt.render(input, "codex"))
end)

test("render: preserves non-command slashes", function()
  local input = "a/b and /command"
  assert_eq("a/b and /prompts:command", prompt.render(input, "codex"))
end)

----------------------------------------------------------------------------------------------------
-- builtin command tests
----------------------------------------------------------------------------------------------------

test("render: codex preserves builtin /help", function()
  local input = "/help"
  assert_eq("/help", prompt.render(input, "codex"))
end)

test("render: codex preserves builtin /clear", function()
  local input = "/clear"
  assert_eq("/clear", prompt.render(input, "codex"))
end)

test("render: codex transforms non-builtin /commit", function()
  local input = "/commit"
  assert_eq("/prompts:commit", prompt.render(input, "codex"))
end)

test("render: codex mixed builtin and non-builtin", function()
  local input = "/help then /commit and /model"
  assert_eq("/help then /prompts:commit and /model", prompt.render(input, "codex"))
end)

test("render: claude preserves all commands (no transformation)", function()
  local input = "/commit and /help"
  assert_eq("/commit and /help", prompt.render(input, "claude"))
end)

test("render: gemini preserves all commands (no transformation)", function()
  local input = "/chat and /custom"
  assert_eq("/chat and /custom", prompt.render(input, "gemini"))
end)

test("render: opencode preserves all commands (no transformation)", function()
  local input = "/init and /custom"
  assert_eq("/init and /custom", prompt.render(input, "opencode"))
end)

----------------------------------------------------------------------------------------------------
-- Summary
----------------------------------------------------------------------------------------------------

print(string.format("\n%d passed, %d failed", passed, failed))

if failed > 0 then
  os.exit(1)
end
