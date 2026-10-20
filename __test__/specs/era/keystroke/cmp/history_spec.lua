local harness = require("__test__.support.harness")
require("__test__.support.cmp.runtime").setup()
local t = harness.new()
local Frecency = require("stl.c.frecency")

t:test("native history restores existing hashed data and preserves its timestamp rings", function()
  local keys = { "lua\0lsp\0lua_ls\0alpha", "python\0lsp\0pyright\0beta", "lua\0buffer\0gamma" }
  local old = Frecency.new({ items = {}, MAX_TIMESTAMPS = 3, normalize = yoz.fn.md5 })
  for index = 1, 5 do
    old:access(keys[index % #keys + 1])
  end
  local native = yoz.completion.new_history(vim.json.decode(vim.json.encode(old:dump())))
  t.assert_same(old:dump(), native:dump(), "loading preserves existing records")
  for _, key in ipairs(keys) do
    t.assert_true(native:score(key) > 0, "loaded records contribute to the new score")
    t.assert_true(native:score(key) < old:score(key), "recent acceptance no longer saturates the bonus immediately")
  end
  for _ = 1, 5 do
    native:access(keys[1])
  end
  local persisted = vim.json.decode(vim.json.encode(native:dump()))
  t.assert_eq(3, #persisted.items[yoz.fn.md5(keys[1])].timestamps, "bounded history")
  local restored = Frecency.deserialize({ data = persisted, normalize = yoz.fn.md5 })
  t.assert_eq(30, restored:score(keys[1]), "existing data reader understands native output")
  native:load({ items = {} })
  t.assert_eq(0, native:score(keys[1]), "workspace load replaces old history")
  native:load(persisted)
  t.assert_same(persisted, native:dump(), "workspace reload restores history")
  t.assert_true(native:score(keys[1]) <= 12, "three retained accepts are bounded by four points each")
end)

t:test("malformed history cannot partially replace a live history", function()
  local native = yoz.completion.new_history()
  native:access("lua\0alpha")
  local before = native:dump()
  local ok = pcall(native.load, native, { MAX_TIMESTAMPS = 0, items = {} })
  t.assert_eq(false, ok, "invalid ring limit rejected")
  t.assert_same(before, native:dump(), "failed load is atomic")
  ok = pcall(native.load, native, { items = { invalid = { timestamps = { 1 }, idx = 1 } } })
  t.assert_eq(false, ok, "malformed digest rejected")
  t.assert_same(before, native:dump(), "bad entry cannot replace live history")
end)

t:run()
