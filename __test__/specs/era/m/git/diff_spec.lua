local git_buffer = require("__test__.support.git_buffer")
local harness = require("__test__.support.harness")
local diff = require("era.m.git.diff")

local t = harness.new()
git_buffer.with_futures(t)

-- Each input runs through run_diff and, under its own case name where it has one, through run_diff_future, which
-- must produce the same hunks.
for _, case in ipairs({
  {
    sync = "empty files",
    future = "empty files",
    old = {},
    new = {},
    check = function(hunks)
      t.assert_eq(0, #hunks, "hunk count")
    end,
  },
  {
    sync = "identical files",
    old = { "line1", "line2", "" },
    new = { "line1", "line2", "" },
    check = function(hunks)
      t.assert_eq(0, #hunks, "hunk count")
    end,
  },
  {
    sync = "new file (all additions)",
    old = {},
    new = { "line1", "line2", "" },
    check = function(hunks)
      t.assert_eq(1, #hunks, "hunk count")
      t.assert_eq("add", hunks[1].type, "hunk type")
      t.assert_eq(2, hunks[1].added.count, "added count")
    end,
  },
  {
    sync = "deleted file (all deletions)",
    old = { "line1", "line2", "" },
    new = {},
    check = function(hunks)
      t.assert_eq(1, #hunks, "hunk count")
      t.assert_eq("delete", hunks[1].type, "hunk type")
      t.assert_eq(2, hunks[1].removed.count, "removed count")
    end,
  },
  {
    sync = "single line change",
    future = "basic functionality",
    old = { "old", "" },
    new = { "new", "" },
    check = function(hunks)
      t.assert_eq(1, #hunks, "hunk count")
      t.assert_eq("change", hunks[1].type, "hunk type")
      t.assert_eq(1, hunks[1].added.start, "added start")
    end,
  },
  {
    sync = "content with pipe character",
    old = { "a|b|c", "" },
    new = { "a|b|c|d", "" },
    check = function(hunks)
      t.assert_eq(1, #hunks, "hunk count")
      t.assert_eq("a|b|c|d", hunks[1].added.lines[1], "content preserved")
    end,
  },
  {
    future = "content with special characters",
    old = { "a|b;c\td", "" },
    new = { "x|y;z\tw", "" },
    check = function(hunks)
      t.assert_eq(1, #hunks, "hunk count")
      t.assert_eq("x|y;z\tw", hunks[1].added.lines[1], "content preserved")
    end,
  },
  {
    -- Changes two unchanged lines apart stay separate hunks.
    sync = "nearby changes remain independent authoritative hunks",
    future = "preserves independent nearby changes",
    old = { "line1", "line2", "line3", "line4", "" },
    new = { "modified1", "line2", "line3", "modified4", "" },
    check = function(hunks)
      t.assert_eq(2, #hunks, "hunk count")
      t.assert_eq(1, hunks[1].added.start, "first start")
      t.assert_eq(4, hunks[2].added.start, "second start")
    end,
  },
  {
    sync = "top insertion preserves the zero original anchor",
    old = { "b", "c", "" },
    new = { "a", "b", "c", "" },
    check = function(hunks)
      t.assert_eq(0, hunks[1].removed.start, "original anchor")
      t.assert_eq("@@ -0,0 +1,1 @@", hunks[1].head, "header")
    end,
  },
}) do
  if case.sync then
    t:test("run_diff: " .. case.sync, function()
      case.check(diff.run_diff(case.old, case.new))
    end)
  end
  if case.future then
    t:test("run_diff_future: " .. case.future, function()
      local hunks = t.await(diff.run_diff_future(case.old, case.new)) ---@type era.m.git.Hunk[]|nil
      t.assert_true(hunks ~= nil, "result should not be nil")
      ---@cast hunks era.m.git.Hunk[]
      case.check(hunks)
      t.assert_same(diff.run_diff(case.old, case.new), hunks, "run_diff parity")
    end)
  end
end

t:test("run_diff: final-newline-only changes are represented", function()
  local removed = diff.run_diff({ "a", "b", "" }, { "a", "b" })
  local added = diff.run_diff({ "a", "b" }, { "a", "b", "" })

  t.assert_eq(1, #removed, "removed final newline")
  t.assert_true(removed[1].added.no_nl_at_eof == true, "missing newline marker")
  t.assert_eq(1, #added, "added final newline")
  t.assert_true(added[1].removed.no_nl_at_eof == true, "original missing newline marker")
end)

t:test("filter_secondary: nil inputs", function()
  local result = diff.filter_secondary(nil, nil)
  t.assert_eq(nil, result, "nil result")
end)

t:test("filter_secondary: duplicate provider changes are hidden", function()
  local primary = diff.run_diff({ "old", "" }, { "new", "" })
  local secondary = diff.run_diff({ "old", "" }, { "new", "" })
  local result = diff.filter_secondary(primary, secondary)
  t.assert_eq(nil, result, "all common filtered")
end)

t:test("filter_secondary: same modified range with different originals stays visible", function()
  local primary = diff.run_diff({ "index", "" }, { "buffer", "" })
  local secondary = diff.run_diff({ "head", "" }, { "buffer", "" })
  local result = diff.filter_secondary(primary, secondary)
  t.assert_eq(1, result and #result or 0, "secondary hunk preserved")
end)

t:test("filter_secondary: original final-newline differences stay visible", function()
  local primary = diff.run_diff({ "a" }, { "b" })
  local secondary = diff.run_diff({ "a", "" }, { "b" })
  local result = diff.filter_secondary(primary, secondary)
  t.assert_eq(1, result and #result or 0, "EOF-distinct secondary hunk")
end)

t:test("filter_secondary: searches every primary hunk sharing an added start", function()
  local first = diff.run_diff({ "first", "" }, { "buffer", "" })[1]
  local matching = diff.run_diff({ "matching", "" }, { "buffer", "" })[1]
  local secondary = diff.run_diff({ "matching", "" }, { "buffer", "" })

  local result = diff.filter_secondary({ first, matching }, secondary)

  t.assert_eq(nil, result, "later matching hunk filtered")
end)

t:run()
