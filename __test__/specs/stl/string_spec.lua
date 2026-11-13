local harness = require("__test__.support.harness")

local t = harness.new()

local String = require("stl.string")

t:test("a filepath location is its integer suffix, so drive letters and colons in names stay in the path", function()
  local cases = {
    { "/repo/a.lua:3:1:2", { "/repo/a.lua", 3, 1, 2 } },
    -- An LSP reference whose range ends on another line has no end column.
    { "/repo/a.lua:3:1:-1", { "/repo/a.lua", 3, 1, -1 } },
    { "/repo/a.lua:3:1", { "/repo/a.lua", 3, 1 } },
    { "/repo/a.lua:3", { "/repo/a.lua", 3 } },
    { "/repo/a.lua", { "/repo/a.lua" } },
    { "C:/repo/src/main.lua:10:5:9", { "C:/repo/src/main.lua", 10, 5, 9 } },
    { "/repo/a:b.lua:3:1:2", { "/repo/a:b.lua", 3, 1, 2 } },
  }
  for _, case in ipairs(cases) do
    t.assert_same(case[2], { String.parse_filepath_with_location(case[1]) }, case[1])
  end
end)

t:run()
