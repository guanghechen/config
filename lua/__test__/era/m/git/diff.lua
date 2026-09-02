---@diagnostic disable: undefined-global
--- Test for era.m.git.diff module
--- Run with: nvim -l lua/__test__/era/m/git/diff.lua

local bootstrap = require("__test__.bootstrap")
local harness = require("__test__.harness")
local diff = require("era.m.git.diff")

local t = harness.new("era.m.git.diff")
bootstrap.with_stl_c(t)

----------------------------------------------------------------------------------------------------
-- run_diff tests
----------------------------------------------------------------------------------------------------

t:test("run_diff: empty files", function()
  local hunks = diff.run_diff({}, {})
  t.assert_eq(0, #hunks, "hunk count")
end)

t:test("run_diff: identical files", function()
  local hunks = diff.run_diff({ "line1", "line2", "" }, { "line1", "line2", "" })
  t.assert_eq(0, #hunks, "hunk count")
end)

t:test("run_diff: new file (all additions)", function()
  local hunks = diff.run_diff({}, { "line1", "line2", "" })
  t.assert_eq(1, #hunks, "hunk count")
  t.assert_eq("add", hunks[1].type, "hunk type")
  t.assert_eq(2, hunks[1].added.count, "added count")
end)

t:test("run_diff: deleted file (all deletions)", function()
  local hunks = diff.run_diff({ "line1", "line2", "" }, {})
  t.assert_eq(1, #hunks, "hunk count")
  t.assert_eq("delete", hunks[1].type, "hunk type")
  t.assert_eq(2, hunks[1].removed.count, "removed count")
end)

t:test("run_diff: single line change", function()
  local hunks = diff.run_diff({ "old", "" }, { "new", "" })
  t.assert_eq(1, #hunks, "hunk count")
  t.assert_eq("change", hunks[1].type, "hunk type")
  t.assert_eq(1, hunks[1].added.start, "added start")
end)

t:test("run_diff: content with pipe character", function()
  local hunks = diff.run_diff({ "a|b|c", "" }, { "a|b|c|d", "" })
  t.assert_eq(1, #hunks, "hunk count")
  t.assert_eq("a|b|c|d", hunks[1].added.lines[1], "content preserved")
end)

----------------------------------------------------------------------------------------------------
-- authoritative LineChange tests
----------------------------------------------------------------------------------------------------

t:test("run_diff: nearby changes remain independent authoritative hunks", function()
  local old = { "line1", "line2", "line3", "line4", "" }
  local new = { "modified1", "line2", "line3", "modified4", "" }
  local hunks = diff.run_diff(old, new)

  t.assert_eq(2, #hunks, "hunk count")
  t.assert_eq(1, hunks[1].added.start, "first start")
  t.assert_eq(4, hunks[2].added.start, "second start")
end)

t:test("run_diff: top insertion preserves the zero original anchor", function()
  local hunks = diff.run_diff({ "b", "c", "" }, { "a", "b", "c", "" })
  t.assert_eq(0, hunks[1].removed.start, "original anchor")
  t.assert_eq("@@ -0,0 +1,1 @@", hunks[1].head, "header")
end)

t:test("run_diff: final-newline-only changes are represented", function()
  local removed = diff.run_diff({ "a", "b", "" }, { "a", "b" })
  local added = diff.run_diff({ "a", "b" }, { "a", "b", "" })

  t.assert_eq(1, #removed, "removed final newline")
  t.assert_true(removed[1].added.no_nl_at_eof == true, "missing newline marker")
  t.assert_eq(1, #added, "added final newline")
  t.assert_true(added[1].removed.no_nl_at_eof == true, "original missing newline marker")
end)

----------------------------------------------------------------------------------------------------
-- run_diff_future tests
----------------------------------------------------------------------------------------------------

t:test("run_diff_future: basic functionality", function()
  local done = false
  local result_hunks = nil

  diff.run_diff_future({ "old", "" }, { "new", "" }):finally(function(ok, hunks)
    t.assert_eq(true, ok, "future resolved")
    result_hunks = hunks
    done = true
  end)

  vim.wait(3000, function()
    return done
  end)

  t.assert_eq(true, done, "callback called")
  t.assert_true(result_hunks ~= nil, "result should not be nil")
  ---@cast result_hunks era.m.git.Hunk[]
  t.assert_eq(1, #result_hunks, "hunk count")
  t.assert_eq("change", result_hunks[1].type, "hunk type")
end)

t:test("run_diff_future: empty files", function()
  local done = false
  local result_hunks = nil

  diff.run_diff_future({}, {}):finally(function(ok, hunks)
    t.assert_eq(true, ok, "future resolved")
    result_hunks = hunks
    done = true
  end)

  vim.wait(3000, function()
    return done
  end)

  t.assert_eq(true, done, "callback called")
  t.assert_eq(0, #result_hunks, "hunk count")
end)

t:test("run_diff_future: preserves independent nearby changes", function()
  local done = false
  local result_hunks = nil

  -- Gap = 2, should merge
  local old = { "line1", "line2", "line3", "line4", "" }
  local new = { "modified1", "line2", "line3", "modified4", "" }

  diff.run_diff_future(old, new):finally(function(ok, hunks)
    t.assert_eq(true, ok, "future resolved")
    result_hunks = hunks
    done = true
  end)

  vim.wait(3000, function()
    return done
  end)

  t.assert_eq(true, done, "callback called")
  t.assert_eq(2, #result_hunks, "hunk count")
end)

t:test("run_diff_future: content with special characters", function()
  local done = false
  local result_hunks = nil

  diff.run_diff_future({ "a|b;c\td", "" }, { "x|y;z\tw", "" }):finally(function(ok, hunks)
    t.assert_eq(true, ok, "future resolved")
    result_hunks = hunks
    done = true
  end)

  vim.wait(3000, function()
    return done
  end)

  t.assert_eq(true, done, "callback called")
  t.assert_true(result_hunks ~= nil, "result should not be nil")
  ---@cast result_hunks era.m.git.Hunk[]
  t.assert_eq(1, #result_hunks, "hunk count")
  t.assert_eq("x|y;z\tw", result_hunks[1].added.lines[1], "content preserved")
end)

----------------------------------------------------------------------------------------------------
-- filter_secondary tests
----------------------------------------------------------------------------------------------------

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

t:test("compute_word_diff: native byte diff preserves byte-column ranges", function()
  local changes = diff.compute_word_diff("fooBar", "fooBaz")
  t.assert_eq(1, #changes, "change count")
  t.assert_eq(4, changes[1].old_start, "old start")
  t.assert_eq(6, changes[1].old_end, "old end")
  t.assert_eq(4, changes[1].new_start, "new start")
  t.assert_eq(6, changes[1].new_end, "new end")
end)

t:test("compute_hunk_word_diff: large hunks stay within the popup latency budget", function()
  local old_line = string.rep("a", 500) ---@type string
  local new_line = string.rep("b", 500) ---@type string
  ---@diagnostic disable-next-line: missing-fields
  local hunk = { type = "change", removed = { lines = {} }, added = { lines = {} } } ---@type era.m.git.Hunk
  for index = 1, 200 do
    hunk.removed.lines[index] = old_line
    hunk.added.lines[index] = new_line
  end

  local start = vim.uv.hrtime() ---@type integer
  local changes = diff.compute_hunk_word_diff(hunk)
  local elapsed_ms = (vim.uv.hrtime() - start) / 1e6 ---@type number
  t.assert_eq(200, #changes, "line changes")
  t.assert_true(elapsed_ms < 100, string.format("latency %.2fms", elapsed_ms))
end)

t:run()
