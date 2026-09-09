---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.specs.era.m.git.staging_native" ---@type string

local harness = require("__test__.support.harness")
local staging = require("era.m.git.staging")
local diff = require("era.m.git.diff")
local reference = assert(loadfile("__test__/fixtures/era/m/git/staging_lua_reference.lua"))()
local t = harness.new("era.m.git.staging_native")

---@param expected                      any
---@param actual                        any
---@param context                       string
---@return nil
local function equal(expected, actual, context)
  if not vim.deep_equal(expected, actual) then
    error(context .. "\nexpected: " .. vim.inspect(expected) .. "\nactual: " .. vim.inspect(actual))
  end
end

---@param seed                          integer
---@return fun(limit: integer): integer
local function random(seed)
  return function(limit)
    seed = (seed * 48271) % 2147483647
    return seed % limit + 1
  end
end

t:test("normalization matches the frozen Lua implementation on byte/EOL combinations", function()
  local next_value = random(3701)
  local alphabet = { "a", "\r", "\n", "\0", "\255", "文" }
  local cases = { "", "\n", "\r", "\r\n", "a\r\nb\n", "\r\r\n", "a\r\nb\r\nc\n" }
  for _ = 1, 4000 do
    local bytes = {}
    for _ = 1, next_value(40) do
      bytes[#bytes + 1] = alphabet[next_value(#alphabet)]
    end
    cases[#cases + 1] = table.concat(bytes)
  end
  for _, text in ipairs(cases) do
    for _, eol in ipairs({ "\n", "\r\n" }) do
      local opts = { default_eol = eol, bomb = next_value(2) == 1, encoding = "UTF-8" }
      equal(reference.from_text(text, opts), staging.from_text(text, opts), string.format("text %q", text))
    end
  end
end)

t:test("legacy iconv codecs retain the same bytes and failures", function()
  for _, encoding in ipairs({
    "latin1",
    "LATIN1",
    "iso-8859-1",
    "cp1252",
    "shift_jis",
    "not-a-real-encoding",
  }) do
    for _, eol in ipairs({ "\n", "\r\n" }) do
      for _, text in ipairs({ "", "\n", "caf\195\169", "caf\195\169\n" }) do
        for _, bomb in ipairs({ false, true }) do
          local document = reference.from_text(text, { encoding = encoding, default_eol = eol, bomb = bomb })
          local expected, expected_err = reference.encode(document)
          local actual, actual_err = staging.encode(document)
          equal({ expected, expected_err }, { actual, actual_err }, encoding .. " encode")
          if actual then
            local expected_document, decode_err = reference.from_blob(actual, encoding, eol)
            local actual_document, actual_decode_err = staging.from_blob(actual, encoding, eol)
            equal({ expected_document, decode_err }, { actual_document, actual_decode_err }, encoding .. " decode")
          end
        end
      end
    end
  end
end)

t:test("histogram hunks, selection projection and reconstruction match the Lua oracle", function()
  local next_value = random(1949)
  local alphabet = { "a", "b", "", "c", "\255\0", "你好" }
  for case = 1, 500 do
    local lines = {}
    for _ = 1, next_value(7) - 1 do
      lines[#lines + 1] = alphabet[next_value(#alphabet)]
    end
    local changed = vim.deepcopy(lines)
    for _ = 1, next_value(3) do
      local position = next_value(#changed + 1)
      if next_value(3) == 1 and #changed > 0 then
        table.remove(changed, math.min(position, #changed))
      elseif next_value(2) == 1 then
        table.insert(changed, position, alphabet[next_value(#alphabet)])
      else
        changed[position] = alphabet[next_value(#alphabet)]
      end
    end
    local old_eol = next_value(2) == 1 and "\n" or "\r\n"
    local new_eol = next_value(2) == 1 and "\n" or "\r\n"
    local old_text = table.concat(lines, old_eol) .. (next_value(2) == 1 and old_eol or "")
    local new_text = table.concat(changed, new_eol) .. (next_value(2) == 1 and new_eol or "")
    local original, modified = staging.from_text(old_text), staging.from_text(new_text)
    local hunks = diff.run_diff(original.lines, modified.lines)
    local saved = vim.deepcopy(hunks)
    local context = string.format("case %d: %q -> %q", case, old_text, new_text)
    equal(
      reference.apply_line_changes(original, modified, hunks),
      staging.apply_line_changes(original, modified, hunks),
      context
    )
    for top = 0, #modified.lines + 1 do
      for bot = top, #modified.lines + 1 do
        local label = context .. string.format(" [%d,%d]", top, bot)
        for _, partial in ipairs({ false, true }) do
          local expected = reference.select_hunks(hunks, top, bot, partial)
          local expected_text = #expected > 0 and reference.apply_line_changes(original, modified, expected) or nil
          equal(
            expected_text,
            staging.apply_selection(original, modified, hunks, top, bot, partial and "stage_partial" or "stage"),
            label .. " stage"
          )
          if partial then
            local inverted = reference.invert_hunks(expected)
            equal(
              #inverted > 0 and reference.apply_line_changes(modified, original, inverted) or nil,
              staging.apply_selection(original, modified, hunks, top, bot, "unstage"),
              label .. " unstage"
            )
          end
        end
        local expected, expected_touched = reference.without_range(hunks, top, bot)
        equal(
          expected_touched and reference.apply_line_changes(original, modified, expected) or nil,
          staging.apply_selection(original, modified, hunks, top, bot, "reset"),
          label .. " reset"
        )
      end
    end
    equal(saved, hunks, context .. " input unchanged")
  end
end)

t:test("single-hunk APIs preserve EOF nil/false, anchors and copy ownership", function()
  for _, texts in ipairs({ { "a\nb\nc", "A\nB\nC" }, { "a\nb\n", "b\n" }, { "", "x" }, { "a\nb\n", "A\nb\nC\n" } }) do
    local original, modified = staging.from_text(texts[1]), staging.from_text(texts[2])
    local hunks = diff.run_diff(original.lines, modified.lines)
    for _, hunk in ipairs(hunks) do
      equal({ reference.modified_range(hunk) }, { staging.modified_range(hunk) }, "modified range")
      hunk.removed.no_nl_at_eof = false
      equal(reference.invert(hunk), staging.invert(hunk), "explicit false inverted")
      for top = 0, #modified.lines + 1 do
        for bot = top, #modified.lines + 1 do
          equal(reference.touches(hunk, top, bot), staging.touches(hunk, top, bot), "touches")
          local expected, actual = reference.intersect(hunk, top, bot), staging.intersect(hunk, top, bot)
          equal(expected, actual, "intersection")
          if actual then
            t.assert_true(
              actual ~= hunk and actual.added ~= hunk.added and actual.removed ~= hunk.removed,
              "fresh hunk and nodes"
            )
            t.assert_true(
              actual.added.lines ~= hunk.added.lines and actual.removed.lines ~= hunk.removed.lines,
              "fresh arrays"
            )
          end
        end
      end
      for _, peer in ipairs(hunks) do
        equal(reference.less(hunk, peer), staging.less(hunk, peer), "ordering")
      end
    end
  end
end)

t:test("reconstruction uses captured lines, not a second parse of document.text", function()
  local original = staging.from_text("a\nb\n")
  original.lines[1] = "literal\r"
  local modified = staging.from_text("a\nB\n")
  local hunks = diff.run_diff({ "a", "b", "" }, modified.lines)
  equal(
    reference.apply_line_changes(original, modified, hunks),
    staging.apply_line_changes(original, modified, hunks),
    "literal CR in buffer line"
  )
  original.text = "a\r\nb\n"
  equal(
    reference.apply_line_changes(original, modified, hunks),
    staging.apply_line_changes(original, modified, hunks),
    "mixed-EOL encoded text"
  )
end)

t:test("malformed spans fail before returning writable text", function()
  local original, modified = staging.from_text("a\n"), staging.from_text("A\n")
  local hunks = diff.run_diff(original.lines, modified.lines)
  hunks[1].removed.start = 3
  local ok, err = pcall(staging.apply_line_changes, original, modified, hunks)
  t.assert_false(ok, "out-of-document span refused")
  t.assert_true(tostring(err):find("does not match", 1, true) ~= nil, "actionable error")
  hunks[1].removed.start = -1
  t.assert_false(pcall(staging.apply_line_changes, original, modified, hunks), "negative span refused")
  hunks[1].removed.start = 0
  t.assert_false(pcall(staging.intersect, hunks[1], 1, 1), "zero nonempty span refused")
  for _, value in ipairs({ 1.5, math.huge, -math.huge, 0 / 0, "1" }) do
    hunks[1].removed.start = value
    t.assert_false(pcall(staging.apply_line_changes, original, modified, hunks), "inexact span refused")
  end
  hunks[1].removed.start = 1
  hunks[1].added.lines[2] = "unexpected extra line"
  t.assert_false(
    pcall(staging.apply_selection, original, modified, hunks, 1, 1, "stage"),
    "whole-hunk line count mismatch refused"
  )
  t.assert_false(
    pcall(staging.apply_selection, original, modified, hunks, 1, 1, "stage_partial"),
    "partial-hunk line count mismatch refused"
  )
  hunks[1].added.lines[2] = nil
  t.assert_false(
    pcall(staging.apply_selection, original, modified, hunks, 1.5, 2, "stage_partial"),
    "inexact selection refused"
  )
  t.assert_false(pcall(staging.from_text, "x", { default_eol = "\r" }), "unsupported EOL refused")
end)

t:test("cursor staging stops at the first selected hunk", function()
  local original, modified = staging.from_text("a\nb\n"), staging.from_text("A\nb\n")
  local hunks = diff.run_diff(original.lines, modified.lines)
  hunks[2] = { removed = {}, added = {} }
  t.assert_eq(
    modified.text,
    staging.apply_selection(original, modified, hunks, 1, 1, "stage"),
    "unneeded suffix not read"
  )
  t.assert_false(
    pcall(staging.apply_selection, original, modified, hunks, 1, 1, "stage_partial"),
    "partial selection validates every range"
  )
end)

t:test("large documents and selections do not exhaust mlua's reference stack", function()
  local original = staging.from_text(string.rep("a\n", 40000))
  local modified = staging.from_text(string.rep("b\n", 40000))
  local hunks = diff.run_diff(original.lines, modified.lines)
  t.assert_eq(1, #hunks, "one large hunk")
  t.assert_eq(modified.text, staging.apply_line_changes(original, modified, hunks), "40k added lines")
  t.assert_eq(
    modified.text,
    staging.apply_selection(original, modified, hunks, 1, 40000, "stage_partial"),
    "40k-line selection"
  )
  t.assert_eq(
    original.text,
    staging.apply_selection(original, modified, hunks, 1, 40000, "unstage"),
    "40k-line inversion"
  )

  local old_lines, new_lines, many = {}, {}, {}
  for index = 1, 20000 do
    old_lines[index] = "original " .. index
    new_lines[index] = index % 2 == 1 and ("changed " .. index) or old_lines[index]
    if index % 2 == 1 then
      many[#many + 1] = {
        type = "change",
        head = string.format("@@ -%d,1 +%d,1 @@", index, index),
        vend = index,
        removed = { start = index, count = 1, lines = { old_lines[index] } },
        added = { start = index, count = 1, lines = { new_lines[index] } },
      }
    end
  end
  original = staging.from_text(table.concat(old_lines, "\n") .. "\n")
  modified = staging.from_text(table.concat(new_lines, "\n") .. "\n")
  t.assert_eq(10000, #many, "more hunks than auxiliary stack slots")
  t.assert_eq(modified.text, staging.apply_line_changes(original, modified, many), "10k changes")
  t.assert_eq(
    modified.text,
    staging.apply_selection(original, modified, many, 1, 20000, "stage_partial"),
    "10k selections"
  )
  t.assert_eq(original.text, staging.apply_selection(original, modified, many, 1, 20000, "unstage"), "10k inversions")
  t.assert_eq(original.text, staging.apply_selection(original, modified, many, 1, 20000, "reset"), "reset every hunk")
end)

t:run()
