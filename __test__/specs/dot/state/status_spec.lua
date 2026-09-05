--- Run with: nvim -l __test__/run.lua __test__/specs/dot/state/status_spec.lua
---@diagnostic disable: undefined-global

local harness = require("__test__.support.harness")

local t = harness.new("dot.state.status")

t:test("search state is scoped to its source window and buffer", function()
  local runtime_stl = require("stl")
  t:patch_global("stl", runtime_stl)

  local status = assert(loadfile("lua/dot/state/status.lua"))()
  local winnr = vim.api.nvim_get_current_win()
  local bufnr = vim.api.nvim_win_get_buf(winnr)

  status.set_search(winnr, bufnr, "foo", "2/10")
  local pattern, count = status.get_search(winnr)
  t.assert_eq("foo", pattern, "search pattern")
  t.assert_eq("2/10", count, "search count")
  t.assert_eq(winnr, status.dirty_winline_nr:snapshot(), "published window")

  status.set_search(winnr, bufnr, "next", nil)
  pattern, count = status.get_search(winnr)
  t.assert_eq("next", pattern, "next pattern")
  t.assert_nil(count, "cleared stale count")

  status.clear_search()
  t.assert_nil(status.get_search(winnr), "cleared search")
  t.assert_eq(winnr, status.dirty_winline_nr:snapshot(), "cleared window")

  status.dispose()
  t.assert_true(status.isdisposed(), "disposed status")
end)

t:run()
