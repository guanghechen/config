---@diagnostic disable: undefined-global
--- Test for era.m.git.diff module
--- Run with: nvim -l lua/__test__/era/m/git/diff_test.lua

local diff = require("era.m.git.diff")

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
    error(string.format("%s: expected %s, got %s", msg or "assertion failed", tostring(expected), tostring(actual)))
  end
end

----------------------------------------------------------------------------------------------------
-- run_diff tests
----------------------------------------------------------------------------------------------------

test("run_diff: empty files", function()
  local hunks = diff.run_diff({}, {})
  assert_eq(0, #hunks, "hunk count")
end)

test("run_diff: identical files", function()
  local hunks = diff.run_diff({ "line1", "line2", "" }, { "line1", "line2", "" })
  assert_eq(0, #hunks, "hunk count")
end)

test("run_diff: new file (all additions)", function()
  local hunks = diff.run_diff({}, { "line1", "line2", "" })
  assert_eq(1, #hunks, "hunk count")
  assert_eq("add", hunks[1].type, "hunk type")
  assert_eq(2, hunks[1].added.count, "added count")
end)

test("run_diff: deleted file (all deletions)", function()
  local hunks = diff.run_diff({ "line1", "line2", "" }, {})
  assert_eq(1, #hunks, "hunk count")
  assert_eq("delete", hunks[1].type, "hunk type")
  assert_eq(2, hunks[1].removed.count, "removed count")
end)

test("run_diff: single line change", function()
  local hunks = diff.run_diff({ "old", "" }, { "new", "" })
  assert_eq(1, #hunks, "hunk count")
  assert_eq("change", hunks[1].type, "hunk type")
  assert_eq(1, hunks[1].added.start, "added start")
end)

test("run_diff: content with pipe character", function()
  local hunks = diff.run_diff({ "a|b|c", "" }, { "a|b|c|d", "" })
  assert_eq(1, #hunks, "hunk count")
  assert_eq("a|b|c|d", hunks[1].added.lines[1], "content preserved")
end)

----------------------------------------------------------------------------------------------------
-- denoise_hunks tests
----------------------------------------------------------------------------------------------------

test("denoise_hunks: empty input", function()
  local result = diff.denoise_hunks({})
  assert_eq(0, #result, "result count")
end)

test("denoise_hunks: single hunk unchanged", function()
  local hunks = diff.run_diff({ "old", "" }, { "new", "" })
  local result = diff.denoise_hunks(hunks)
  assert_eq(1, #result, "result count")
end)

test("denoise_hunks: gap <= 2 merges hunks", function()
  -- Modify line 1 and line 4, gap = 2 (lines 2, 3)
  local old = { "line1", "line2", "line3", "line4", "" }
  local new = { "modified1", "line2", "line3", "modified4", "" }
  local hunks = diff.run_diff(old, new)
  assert_eq(1, #hunks, "merged hunk count")
  assert_eq(1, hunks[1].added.start, "merged start")
  assert_eq(4, hunks[1].vend, "merged end")
end)

test("denoise_hunks: gap > 2 keeps separate hunks", function()
  -- Modify line 1 and line 5, gap = 3 (lines 2, 3, 4)
  local old = { "line1", "line2", "line3", "line4", "line5", "" }
  local new = { "modified1", "line2", "line3", "line4", "modified5", "" }
  local hunks = diff.run_diff(old, new)
  assert_eq(2, #hunks, "separate hunk count")
  assert_eq(1, hunks[1].added.start, "first hunk start")
  assert_eq(5, hunks[2].added.start, "second hunk start")
end)

test("denoise_hunks: adjacent hunks (gap = 0) merge", function()
  -- Modify lines 1 and 2, gap = 0
  local old = { "line1", "line2", "line3", "" }
  local new = { "modified1", "modified2", "line3", "" }
  local hunks = diff.run_diff(old, new)
  assert_eq(1, #hunks, "merged hunk count")
end)

test("denoise_hunks: gap = 1 merges", function()
  -- Modify line 1 and line 3, gap = 1 (line 2)
  local old = { "line1", "line2", "line3", "" }
  local new = { "modified1", "line2", "modified3", "" }
  local hunks = diff.run_diff(old, new)
  assert_eq(1, #hunks, "merged hunk count")
end)

test("denoise_hunks: gap = 2 merges", function()
  -- Modify line 1 and line 4, gap = 2 (lines 2, 3)
  local old = { "line1", "line2", "line3", "line4", "" }
  local new = { "modified1", "line2", "line3", "modified4", "" }
  local hunks = diff.run_diff(old, new)
  assert_eq(1, #hunks, "merged hunk count")
end)

test("denoise_hunks: multiple merges in chain", function()
  -- Modify lines 1, 3, 5 with gaps of 1 each - should all merge
  local old = { "l1", "l2", "l3", "l4", "l5", "" }
  local new = { "m1", "l2", "m3", "l4", "m5", "" }
  local hunks = diff.run_diff(old, new)
  assert_eq(1, #hunks, "all merged into one")
end)

----------------------------------------------------------------------------------------------------
-- run_diff_future tests
----------------------------------------------------------------------------------------------------

test("run_diff_future: basic functionality", function()
  local done = false
  local result_hunks = nil

  diff.run_diff_future({ "old", "" }, { "new", "" }):finally(function(ok, hunks)
    assert_eq(true, ok, "future resolved")
    result_hunks = hunks
    done = true
  end)

  vim.wait(3000, function()
    return done
  end)

  assert_eq(true, done, "callback called")
  assert_true(result_hunks ~= nil, "result should not be nil")
  ---@cast result_hunks era.m.git.Hunk[]
  assert_eq(1, #result_hunks, "hunk count")
  assert_eq("change", result_hunks[1].type, "hunk type")
end)

test("run_diff_future: empty files", function()
  local done = false
  local result_hunks = nil

  diff.run_diff_future({}, {}):finally(function(ok, hunks)
    assert_eq(true, ok, "future resolved")
    result_hunks = hunks
    done = true
  end)

  vim.wait(3000, function()
    return done
  end)

  assert_eq(true, done, "callback called")
  assert_eq(0, #result_hunks, "hunk count")
end)

test("run_diff_future: applies denoise", function()
  local done = false
  local result_hunks = nil

  -- Gap = 2, should merge
  local old = { "line1", "line2", "line3", "line4", "" }
  local new = { "modified1", "line2", "line3", "modified4", "" }

  diff.run_diff_future(old, new):finally(function(ok, hunks)
    assert_eq(true, ok, "future resolved")
    result_hunks = hunks
    done = true
  end)

  vim.wait(3000, function()
    return done
  end)

  assert_eq(true, done, "callback called")
  assert_eq(1, #result_hunks, "merged hunk count")
end)

test("run_diff_future: content with special characters", function()
  local done = false
  local result_hunks = nil

  diff.run_diff_future({ "a|b;c\td", "" }, { "x|y;z\tw", "" }):finally(function(ok, hunks)
    assert_eq(true, ok, "future resolved")
    result_hunks = hunks
    done = true
  end)

  vim.wait(3000, function()
    return done
  end)

  assert_eq(true, done, "callback called")
  assert_true(result_hunks ~= nil, "result should not be nil")
  ---@cast result_hunks era.m.git.Hunk[]
  assert_eq(1, #result_hunks, "hunk count")
  assert_eq("x|y;z\tw", result_hunks[1].added.lines[1], "content preserved")
end)

----------------------------------------------------------------------------------------------------
-- filter_common tests
----------------------------------------------------------------------------------------------------

test("filter_common: nil inputs", function()
  local result = diff.filter_common(nil, nil)
  assert_eq(nil, result, "nil result")
end)

test("filter_common: identical hunks filtered out", function()
  local hunks_a = diff.run_diff({ "old", "" }, { "new", "" })
  local hunks_b = diff.run_diff({ "old", "" }, { "new", "" })
  local result = diff.filter_common(hunks_a, hunks_b)
  assert_eq(nil, result, "all common filtered")
end)

test("filter_common: different hunks preserved", function()
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
  assert_eq(1, result and #result or 0, "staged hunk preserved")
end)

----------------------------------------------------------------------------------------------------
-- Summary
----------------------------------------------------------------------------------------------------

print(string.format("\n%d passed, %d failed", passed, failed))

if failed > 0 then
  os.exit(1)
end
