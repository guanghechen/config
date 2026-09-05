--- Run with: nvim -l __test__/run.lua __test__/specs/yoz/canonical_path_spec.lua
---@diagnostic disable: undefined-global

local harness = require("__test__.support.harness")
local native = require("yoz")

local t = harness.new("yoz.canonical_path")

t:test("from_os_path delegates canonical normalization", function()
  local cases = {
    "/workspace/./src/../file.lua",
    [[C:\workspace\.\src\..\file.lua]],
    [[\\server\share\folder\..\file.lua]],
    [[folder\literal.lua]],
  } ---@type string[]

  for _, input in ipairs(cases) do
    for _, keep_trailing_slash in ipairs({ false, true }) do
      local expected = native.canonical_path.normalize(input, keep_trailing_slash) ---@type string
      t.assert_eq(expected, native.canonical_path.from_os_path(input, keep_trailing_slash), input)
    end
  end
end)

t:test("to_os_path converts only canonical separators", function()
  local cases = {
    "/home/alice/work tree/项目/#notes",
    "C:/Users/alice/项目/#notes",
    "C:/",
    "folder/",
    "//server/share/folder/file",
  } ---@type string[]

  for _, input in ipairs(cases) do
    local expected = input:gsub("/", native.path.SEP) ---@type string
    t.assert_eq(expected, native.canonical_path.to_os_path(input), input)
  end

  local native_unc = [[\\server\share\file]]
  t.assert_eq(native_unc, native.canonical_path.to_os_path(native_unc), "native UNC no-op")
end)

t:run()
