require("ark.bootstrap").setup()
local picker = require("__test__.support.picker")
local t = require("__test__.support.harness").new()

t:test("search in buffer takes the matching flags at t1 to t3 and replace at t9 and tr", function()
  local searcher = picker.buffer_searcher(t, { "needle" }, { o_search_pattern = "needle" })
  local descs = {} ---@type table<string, string>
  for _, keymap in ipairs(searcher._finder_keymaps) do
    descs[keymap.key] = keymap.desc
  end
  t.assert_same({
    t1 = "Search in Buffer: toggle fuzzy search",
    t2 = "Search in Buffer: toggle case sensitive",
    t3 = "Search in Buffer: toggle regex search",
    t9 = "Search in Buffer: toggle replace mode",
    tr = "Search in Buffer: toggle replace mode",
  }, { t1 = descs.t1, t2 = descs.t2, t3 = descs.t3, t9 = descs.t9, tr = descs.tr })
end)

t:run()
