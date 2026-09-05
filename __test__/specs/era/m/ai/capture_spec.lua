--- Run with: nvim -l __test__/run.lua __test__/specs/era/m/ai/capture_spec.lua
---@diagnostic disable: undefined-global
--- Test for era.m.ai.capture pure capture-parsing helpers

local harness = require("__test__.support.harness")

local T = require("era.m.ai.capture")
-- The shipped patterns under test (not synthetic copies), so this suite breaks if
-- config drifts to a footer shape the parser no longer recognizes.
local CLAUDE = require("era.m.ai.config").tools.claude

local t = harness.new("era.m.ai.capture")

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

----------------------------------------------------------------------------------------------------
-- extract_input: strip exactly one UI prompt marker (F-001)
----------------------------------------------------------------------------------------------------

t:test("extract_input: strips ❯ marker but keeps a user-typed '>'", function()
  t.assert_eq("> quote this", T.extract_input(frame("❯ > quote this")), "leading user '>' must survive")
end)

t:test("extract_input: strips a single '>' prompt marker", function()
  t.assert_eq("hello world", T.extract_input(frame("> hello world")), "one marker stripped")
end)

t:test("extract_input: normal ❯ prompt", function()
  t.assert_eq("hello world", T.extract_input(frame("❯ hello world")), "marker stripped, content intact")
end)

----------------------------------------------------------------------------------------------------
-- classify: pending vs submitted vs unknown (F-001 regression guard)
----------------------------------------------------------------------------------------------------

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

----------------------------------------------------------------------------------------------------
-- Shipped busy/insert detection against REAL captured Claude footers (R1)
-- Footers below were captured live from a generating Claude pane.
----------------------------------------------------------------------------------------------------

t:test("shipped busy_pattern: matches the live spinner footer", function()
  t.assert_true(
    T.footer_has("✶ Composing… (3s · thinking with xhigh effort)", CLAUDE.busy_pattern),
    "the active spinner must read as busy"
  )
end)

t:test("shipped busy_pattern: matches a multi-word spinner the old anchored shape missed", function()
  -- "Compacting conversation…" — the ellipsis follows the 2nd word, which the prior
  -- "^<glyph> <word>…" pattern could not match; that false-idle is what risked
  -- Escaping a busy agent.
  t.assert_true(
    T.footer_has("✻ Compacting conversation… (12s · thinking)", CLAUDE.busy_pattern),
    "a multi-word busy state must still read as busy"
  )
end)

t:test("shipped busy_pattern: does NOT match an idle footer", function()
  t.assert_false(
    T.footer_has("~/.config/nvim · main · claude-opus-4-8 · Context 80% left", CLAUDE.busy_pattern),
    "an idle footer (no spinner ellipsis) must not read as busy"
  )
end)

t:test("shipped busy_pattern: does NOT match the lingering thinking summary", function()
  -- "Crunched for 4s" stays above the response after thinking; it has no ellipsis and
  -- must not read as an active generation, or delivery would stall waiting for idle.
  t.assert_false(T.footer_has("✻ Crunched for 4s", CLAUDE.busy_pattern), "the thinking summary must not read as busy")
end)

t:test("shipped insert_pattern: matches the modal INSERT indicator", function()
  t.assert_true(T.footer_has("-- INSERT --", CLAUDE.insert_pattern), "the INSERT modeline must match")
end)

----------------------------------------------------------------------------------------------------
-- bottom_lines / footer_has: tmux pads the frame with blank rows up to the pane
-- height and the TUI footer is not pinned to the bottom (R2). Early in a conversation
-- the footer sits well above a tall block of blank rows; a naive last-n window skips
-- it, so footer_has silently never matches => "insert unverified" and false-idle.
----------------------------------------------------------------------------------------------------

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
