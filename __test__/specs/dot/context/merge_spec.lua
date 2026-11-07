require("ark.bootstrap").setup()
local t = require("__test__.support.harness").new()
local merge = require("dot.context.merge")

---@param fields                        table<string, unknown>
---@return table<string, table<string, unknown>>
local function state(fields)
  return { option = fields }
end

t:test("fingerprints ignore the order a table was built in", function()
  local first, second = {}, {}
  first.a, first.b = 1, { x = true, y = false }
  second.b, second.a = { y = false, x = true }, 1
  t.assert_eq(merge.fingerprints(state(first)).option.b, merge.fingerprints(state(second)).option.b)
end)

t:test("fingerprints take any bytes, as a Linux filename may hold", function()
  local fingerprints = merge.fingerprints(state({ latin1 = "/srv/caf\xe9.txt", utf8 = "/srv/café.txt" }))
  t.assert_true(fingerprints.option.latin1 ~= fingerprints.option.utf8)
end)

t:test("a field counts as changed when its value moves, appears or goes, but not when it comes back", function()
  local baseline = merge.fingerprints(state({ a = 1, b = 2 }))
  t.assert_eq(false, merge.changed(baseline, merge.fingerprints(state({ a = 1, b = 2 }))), "unchanged")
  t.assert_eq(true, merge.changed(baseline, merge.fingerprints(state({ a = 3, b = 2 }))), "moved")
  t.assert_eq(true, merge.changed(baseline, merge.fingerprints(state({ a = 1, b = 2, c = 4 }))), "set")
  t.assert_eq(true, merge.changed(baseline, merge.fingerprints(state({ a = 1 }))), "cleared")
end)

t:test("each field keeps this instance's value only where it changed it", function()
  local baseline = merge.fingerprints(state({ mine = 1, theirs = 1, both = 1, cleared = 1, kept = 1 }))
  local ours = state({ mine = 2, theirs = 1, both = 2, kept = 1 })
  local disk = state({ mine = 1, theirs = 3, both = 3, cleared = 1, set = 4 })

  local merged = merge.merge(baseline, merge.fingerprints(ours), ours, disk).option

  t.assert_eq(2, merged.mine, "changed here")
  t.assert_eq(3, merged.theirs, "changed by an instance that saved since")
  t.assert_eq(2, merged.both, "changed by both: the later save wins")
  t.assert_eq(nil, merged.cleared, "cleared here")
  t.assert_eq(nil, merged.kept, "cleared by the instance that saved since")
  t.assert_eq(4, merged.set, "set by the instance that saved since")
end)

t:test("without a readable file the whole state is written", function()
  local ours = state({ a = 1 })
  local baseline = merge.fingerprints(state({ a = 2, b = 3 }))
  t.assert_true(merge.merge(baseline, merge.fingerprints(ours), ours, nil) == ours)
end)

t:run()
