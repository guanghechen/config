local harness = require("__test__.support.harness")

local T = require("era.m.ai.capture")
-- The shipped patterns under test (not synthetic copies), so this suite breaks if
-- config drifts to a footer shape the parser no longer recognizes.
local CLAUDE = require("era.m.ai.config").tools.claude

local t = harness.new()

--- Build a capture frame: header, the input box framed by two horizontal rules,
--- then a footer line (idle by default — pass `footer` for a busy/other state).
---@param prompt_line                   string
---@param footer                        ?string
---@return string
local function frame(prompt_line, footer)
  return table.concat({
    "context above",
    string.rep("─", 30),
    prompt_line,
    string.rep("─", 30),
    footer or "~/.config/nvim · main · claude-opus-4-8 · Context 80% left",
  }, "\n")
end

for _, case in ipairs({
  {
    name = "extract_input: strips ❯ marker but keeps a user-typed '>'",
    prompt_line = "❯ > quote this",
    input = "> quote this",
    message = "leading user '>' must survive",
  },
  {
    name = "extract_input: strips a single '>' prompt marker",
    prompt_line = "> hello world",
    input = "hello world",
    message = "one marker stripped",
  },
  {
    name = "extract_input: normal ❯ prompt",
    prompt_line = "❯ hello world",
    input = "hello world",
    message = "marker stripped, content intact",
  },
}) do
  t:test(case.name, function()
    t.assert_eq(case.input, T.extract_input(frame(case.prompt_line)), case.message)
  end)
end

t:test("classify: '>'-prefixed prompt still in the box is pending, not submitted", function()
  local sig = T.make_signature("> quote this")
  t.assert_eq("pending", T.classify(frame("❯ > quote this"), sig, nil), "must not report a false success")
end)

t:test("classify: normal prompt still in the box is pending", function()
  local sig = T.make_signature("hello world")
  t.assert_eq("pending", T.classify(frame("❯ hello world"), sig, nil), "text still pending")
end)

t:test("classify: cleared input box is submitted", function()
  local sig = T.make_signature("hello world")
  t.assert_eq("submitted", T.classify(frame(""), sig, nil), "box emptied => submitted")
end)

t:test("classify: an unparseable frame is unknown", function()
  local sig = T.make_signature("hello world")
  t.assert_eq("unknown", T.classify("no horizontal rules here", sig, nil), "cannot judge => unknown")
end)

for _, case in ipairs({
  {
    name = "shipped busy_pattern: matches the live spinner footer",
    footer = "✶ Composing… (3s · thinking with xhigh effort)",
    busy = true,
    message = "the active spinner must read as busy",
  },
  {
    name = "shipped busy_pattern: matches a multi-word spinner the old anchored shape missed",
    -- "Compacting conversation…" — the ellipsis follows the 2nd word, which the prior
    -- "^<glyph> <word>…" pattern could not match; that false-idle is what risked
    -- Escaping a busy agent.
    footer = "✻ Compacting conversation… (12s · thinking)",
    busy = true,
    message = "a multi-word busy state must still read as busy",
  },
  {
    name = "shipped busy_pattern: does NOT match an idle footer",
    footer = "~/.config/nvim · main · claude-opus-4-8 · Context 80% left",
    busy = false,
    message = "an idle footer (no spinner ellipsis) must not read as busy",
  },
  {
    name = "shipped busy_pattern: does NOT match the lingering thinking summary",
    -- "Crunched for 4s" stays above the response after thinking; it has no ellipsis and
    -- must not read as an active generation, or delivery would stall waiting for idle.
    footer = "✻ Crunched for 4s",
    busy = false,
    message = "the thinking summary must not read as busy",
  },
}) do
  t:test(case.name, function()
    t.assert_eq(case.busy, T.footer_has(case.footer, CLAUDE.busy_pattern), case.message)
  end)
end

t:test("shipped insert_pattern: matches the modal INSERT indicator", function()
  t.assert_true(T.footer_has("-- INSERT --", CLAUDE.insert_pattern), "the INSERT modeline must match")
end)

t:test("bottom_lines: drops trailing blank rows so the window ends at the last real line", function()
  local padded = "alpha\nbravo\ncharlie" .. string.rep("\n", 12)
  local got = T.bottom_lines(padded, 2)
  t.assert_eq(2, #got, "exactly n lines returned")
  t.assert_eq("bravo", got[1], "window ends at the last non-blank line")
  t.assert_eq("charlie", got[2], "last real line included, not a blank pad row")
end)

t:test("footer_has: finds the INSERT marker above a tall block of trailing blank rows", function()
  local padded = frame("❯ ", "-- INSERT -- ⏵⏵ bypass permissions on") .. string.rep("\n", 15)
  t.assert_true(T.footer_has(padded, CLAUDE.insert_pattern), "INSERT must be found above the blank tail")
end)

t:test("footer_has: finds the busy spinner above a tall block of trailing blank rows", function()
  local padded = frame("❯ hello", "✶ Composing… (3s · thinking)") .. string.rep("\n", 15)
  t.assert_true(T.footer_has(padded, CLAUDE.busy_pattern), "the spinner must be found above the blank tail")
end)

t:test("classify: a busy frame is submitted via the shipped busy_pattern", function()
  local sig = T.make_signature("hello world")
  -- Our text is still in the box, but a busy footer means the agent already took it
  -- and is generating => submitted (and we must never Escape it).
  local busy = frame("❯ hello world", "✶ Composing… (3s · thinking with xhigh effort)")
  t.assert_eq("submitted", T.classify(busy, sig, CLAUDE.busy_pattern), "busy => generating => submitted")
end)

t:run()
