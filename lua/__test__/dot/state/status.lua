---@diagnostic disable: undefined-global

local harness = require("__test__.harness")

local t = harness.new("dot.state.status")

t:test("search count is scoped to its source window and buffer", function()
  local runtime_stl = require("stl")
  t:patch_global("stl", runtime_stl)

  local status = assert(loadfile("lua/dot/state/status.lua"))()
  local winnr = vim.api.nvim_get_current_win()
  local bufnr = vim.api.nvim_win_get_buf(winnr)

  status.set_search_count(winnr, bufnr, "[2/10]")
  t.assert_eq("[2/10]", status.get_search_count(winnr), "source window")
  t.assert_eq(winnr, status.dirty_winline_nr:snapshot(), "published window")

  status.clear_search_count()
  t.assert_nil(status.get_search_count(winnr), "cleared count")
  t.assert_eq(winnr, status.dirty_winline_nr:snapshot(), "cleared window")

  status.dispose()
end)

t:run()
