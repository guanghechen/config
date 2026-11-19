require("ark.bootstrap").setup()
local t = require("__test__.support.harness").new()

t:test("Search in Files takes its settings, exclude, gitignore and match limit flags at t0, t7, t8 and tl", function()
  local props = nil ---@type era.m.searcher.IFiletreeComposerProps|nil
  t:patch_table(era.m.searcher.FiletreeComposer, "new", function(actual_props)
    props = actual_props
    return {}
  end)
  t:patch_table(stl.fn, "observe", function() end)
  assert(loadfile("lua/era/fn/search-in-files.lua"))()
  local captured = assert(props)
  local keys = {} ---@type string[]
  for _, flag in ipairs(vim.list_extend(vim.list_slice(captured.flags_prepend), captured.flags_append)) do
    keys[#keys + 1] = flag.key
  end
  t.assert_same({ "t0", "t7", "t8", "tl" }, keys)
end)

t:run()
