require("ark.bootstrap").setup()
local t = require("__test__.support.harness").new()
local Diff = require("era.m.git_files.diff")

t:test("source line numbers advance independently across replacements and separate hunks", function()
  local rows = Diff.parse({
    "diff --git a/example.lua b/example.lua",
    "index 123..456 100644",
    "--- a/example.lua",
    "+++ b/example.lua",
    "@@ -10,4 +10,5 @@ local function example()",
    " context",
    "-old first",
    "-old second",
    "+new first",
    "+new second",
    "+new third",
    " tail",
    "@@ -30 +31 @@",
    "-before",
    "+after",
  }, false)
  local actual = {}
  for _, row in ipairs(rows) do
    actual[#actual + 1] = { row.kind, row.old_lnum or false, row.new_lnum or false }
  end
  t.assert_same({
    { "hunk", false, false },
    { "context", 10, 10 },
    { "delete", 11, false },
    { "delete", 12, false },
    { "add", false, 11 },
    { "add", false, 12 },
    { "add", false, 13 },
    { "context", 13, 14 },
    { "hunk", false, false },
    { "delete", 30, false },
    { "add", false, 31 },
  }, actual)
  t.assert_eq("@@ -10,4 +10,5 @@ local function example()", rows[1].text)
  t.assert_true(#rows[3].words > 0)
  t.assert_true(rows[3].words == rows[5].words, "word highlights pair replacement rows within a change block")
  t.assert_nil(rows[7].words, "an unmatched addition keeps its full-line highlight")
  t.assert_nil(rows[8].words, "context does not inherit word changes")
end)

t:test("new and deleted files leave the absent side blank and retain missing-newline markers", function()
  local rows = Diff.parse({ "@@ -0,0 +1,2 @@", "+first", "+last", "\\ No newline at end of file" }, false)
  t.assert_eq(3, #rows)
  t.assert_eq("hunk", rows[1].kind)
  t.assert_nil(rows[2].old_lnum)
  t.assert_eq(1, rows[2].new_lnum)
  t.assert_eq(2, rows[3].new_lnum)
  t.assert_true(rows[3].missing_newline)
  rows = Diff.parse({ "@@ -1,2 +0,0 @@", "-first", "-last", "\\ No newline at end of file" }, false)
  t.assert_eq(3, #rows)
  t.assert_eq("hunk", rows[1].kind)
  t.assert_eq(1, rows[2].old_lnum)
  t.assert_eq(2, rows[3].old_lnum)
  t.assert_nil(rows[3].new_lnum)
  t.assert_true(rows[3].missing_newline)
end)

t:test("patch-like source text is preserved and unicode word ranges use byte offsets", function()
  local prefix = "local 文本 = "
  local rows = Diff.parse({
    "@@ -1,3 +1,3 @@",
    "--- old source",
    "-@@ old source",
    "-" .. prefix .. "before",
    "+++ new source",
    "+@@ new source",
    "+" .. prefix .. "after",
  }, false)
  t.assert_eq("-- old source", rows[2].text)
  t.assert_eq("@@ old source", rows[3].text)
  t.assert_eq("++ new source", rows[5].text)
  t.assert_eq("@@ new source", rows[6].text)
  t.assert_eq(#prefix, rows[4].words[1].old_start)
  t.assert_eq(#prefix, rows[7].words[1].new_start)
  t.assert_eq(#rows[4].text, rows[4].words[1].old_end)
  t.assert_eq(#rows[7].text, rows[7].words[1].new_end)
end)

t:test("metadata-only and binary changes have compact descriptions without invented line numbers", function()
  for _, case in ipairs({
    { { "old mode 100644", "new mode 100755" }, "File mode 100644 → 100755" },
    { { "new file mode 100644" }, "New empty file · mode 100644" },
    { { "deleted file mode 100644" }, "Empty file deleted · mode 100644" },
    { { "rename from old.lua", "rename to new.lua" }, "Renamed from old.lua" },
    { { "Binary files a/image.png and b/image.png differ" }, "Binary file changed." },
    { {}, "No textual changes." },
  }) do
    local rows = Diff.parse(case[1], false)
    t.assert_eq(case[2], rows[1].text)
    for _, row in ipairs(rows) do
      t.assert_eq("info", row.kind)
      t.assert_nil(row.old_lnum)
      t.assert_nil(row.new_lnum)
    end
  end
end)

t:test("truncated hunks keep complete source rows and an explicit limit marker", function()
  local rows = Diff.parse({ "@@ -0,0 +1,5000 @@", "+one", "+two" }, true)
  t.assert_eq("@@ -0,0 +1,5000 @@", rows[1].text)
  t.assert_eq("one", rows[2].text)
  t.assert_eq(2, rows[3].new_lnum)
  t.assert_eq("info", rows[4].kind)
  t.assert_eq("Diff preview truncated.", rows[4].text)
  t.assert_nil(rows[4].new_lnum)
end)

t:test("incomplete or combined patches never publish misleading two-way line numbers", function()
  for _, lines in ipairs({
    { "@@ -1,2 +1 @@", "-before", "+after" },
    { "@@ -1 +1 @@", "unexpected content" },
    { "@@ -0 +1 @@", "+after" },
    { "diff --cc conflict.lua", "@@@ -1,2 -1,2 +1,3 @@@" },
  }) do
    local rows = Diff.parse(lines, false)
    t.assert_eq(1, #rows)
    t.assert_eq("info", rows[1].kind)
    t.assert_nil(rows[1].old_lnum)
    t.assert_nil(rows[1].new_lnum)
  end
end)

t:run()
