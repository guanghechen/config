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
-- denoise_hunks tests
----------------------------------------------------------------------------------------------------

t:test("denoise_hunks: empty input", function()
  local result = diff.denoise_hunks({})
  t.assert_eq(0, #result, "result count")
end)

t:test("denoise_hunks: single hunk unchanged", function()
  local hunks = diff.run_diff({ "old", "" }, { "new", "" })
  local result = diff.denoise_hunks(hunks)
  t.assert_eq(1, #result, "result count")
end)

t:test("denoise_hunks: gap <= 2 merges hunks", function()
  -- Modify line 1 and line 4, gap = 2 (lines 2, 3)
  local old = { "line1", "line2", "line3", "line4", "" }
  local new = { "modified1", "line2", "line3", "modified4", "" }
  local hunks = diff.run_diff(old, new)
  t.assert_eq(1, #hunks, "merged hunk count")
  t.assert_eq(1, hunks[1].added.start, "merged start")
  t.assert_eq(4, hunks[1].vend, "merged end")
end)

t:test("denoise_hunks: gap > 2 keeps separate hunks", function()
  -- Modify line 1 and line 5, gap = 3 (lines 2, 3, 4)
  local old = { "line1", "line2", "line3", "line4", "line5", "" }
  local new = { "modified1", "line2", "line3", "line4", "modified5", "" }
  local hunks = diff.run_diff(old, new)
  t.assert_eq(2, #hunks, "separate hunk count")
  t.assert_eq(1, hunks[1].added.start, "first hunk start")
  t.assert_eq(5, hunks[2].added.start, "second hunk start")
end)

t:test("denoise_hunks: adjacent hunks (gap = 0) merge", function()
  -- Modify lines 1 and 2, gap = 0
  local old = { "line1", "line2", "line3", "" }
  local new = { "modified1", "modified2", "line3", "" }
  local hunks = diff.run_diff(old, new)
  t.assert_eq(1, #hunks, "merged hunk count")
end)

t:test("denoise_hunks: gap = 1 merges", function()
  -- Modify line 1 and line 3, gap = 1 (line 2)
  local old = { "line1", "line2", "line3", "" }
  local new = { "modified1", "line2", "modified3", "" }
  local hunks = diff.run_diff(old, new)
  t.assert_eq(1, #hunks, "merged hunk count")
end)

t:test("denoise_hunks: gap = 2 merges", function()
  -- Modify line 1 and line 4, gap = 2 (lines 2, 3)
  local old = { "line1", "line2", "line3", "line4", "" }
  local new = { "modified1", "line2", "line3", "modified4", "" }
  local hunks = diff.run_diff(old, new)
  t.assert_eq(1, #hunks, "merged hunk count")
end)

t:test("denoise_hunks: multiple merges in chain", function()
  -- Modify lines 1, 3, 5 with gaps of 1 each - should all merge
  local old = { "l1", "l2", "l3", "l4", "l5", "" }
  local new = { "m1", "l2", "m3", "l4", "m5", "" }
  local hunks = diff.run_diff(old, new)
  t.assert_eq(1, #hunks, "all merged into one")
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

t:test("run_diff_future: applies denoise", function()
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
  t.assert_eq(1, #result_hunks, "merged hunk count")
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
-- filter_common tests
----------------------------------------------------------------------------------------------------

t:test("filter_common: nil inputs", function()
  local result = diff.filter_common(nil, nil)
  t.assert_eq(nil, result, "nil result")
end)

t:test("filter_common: identical hunks filtered out", function()
  local hunks_a = diff.run_diff({ "old", "" }, { "new", "" })
  local hunks_b = diff.run_diff({ "old", "" }, { "new", "" })
  local result = diff.filter_common(hunks_a, hunks_b)
  t.assert_eq(nil, result, "all common filtered")
end)

t:test("filter_common: different hunks preserved", function()
  -- Simulate: HEAD="a", Index="b", Buffer="c"
  -- hunks_head = diff(HEAD, Buffer) = diff("a", "c") -> change at line 1
  -- hunks_index = diff(Index, Buffer) = diff("b", "c") -> change at line 1
  -- Result should be hunks in head but not in index (staged changes)
  -- Since both have changes at same position with same new content, they are "common"
  -- But the old content differs, so the HEAD hunk represents the staged change

  -- Better test: HEAD="original", Index="modified", Buffer="modified" (no unstaged changes)
  local hunks_head = diff.run_diff({ "original", "" }, { "modified", "" })
  local hunks_index = diff.run_diff({ "modified", "" }, { "modified", "" }) -- empty
  local result = diff.filter_common(hunks_head, hunks_index)
  -- hunks_head has a change, hunks_index is empty, so the change is "staged only"
  t.assert_eq(1, result and #result or 0, "staged hunk preserved")
end)

t:run()
