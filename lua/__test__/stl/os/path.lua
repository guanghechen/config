---@diagnostic disable: undefined-global
--- Test for stl.os.path module
--- Run with: nvim -l lua/__test__/stl/os/path.lua

local bootstrap = require("__test__.bootstrap")
local harness = require("__test__.harness")
local native = require("yoz")

local t = harness.new("stl.os.path")

bootstrap.with_runtime(t, {
  stl = { env = { PATH_SEP = native.path.SEP } },
  yoz = native,
})

local path = require("stl.os.path")

local UNARY_CASES = {
  { input = ".", keep = false },
  { input = "./", keep = true },
  { input = "../project/./src", keep = false },
  { input = "/", keep = true },
  { input = "/home/alice/work tree/../项目/#notes/", keep = true },
  { input = "C:\\Users\\alice\\..\\项目\\#notes\\", keep = true },
  { input = "//server/share/folder/../file", keep = false },
} ---@type { input: string, keep: boolean }[]

t:test("normalize and from_os match generic slash normalization", function()
  for _, case in ipairs(UNARY_CASES) do
    local expected = native.path.normalize(case.input, case.keep, "/") ---@type string
    t.assert_eq(expected, path.normalize(case.input, case.keep), "normalize " .. case.input)
    t.assert_eq(expected, path.from_os(case.input, case.keep), "from_os " .. case.input)
  end
end)

t:test("normalize and from_os preserve wrapper boundary behavior", function()
  for _, input in ipairs({ "folder/", "folder\\" }) do
    t.assert_eq("folder/", path.normalize(input), "normalize inferred trailing slash")
    t.assert_eq("folder/", path.from_os(input), "from_os inferred trailing slash")
  end

  for _, input in ipairs({ "", false }) do
    t.assert_eq("", path.normalize(input), "normalize empty or non-string")
    t.assert_eq("", path.from_os(input), "from_os empty or non-string")
  end

  for _, input in ipairs({ "diffview://null", "git+ssh://example/repo" }) do
    t.assert_eq(input, path.normalize(input), "normalize URI-like")
    t.assert_eq(input, path.from_os(input), "from_os URI-like")
  end
end)

t:test("to_os emits the native separator and preserves wrapper boundaries", function()
  local cases = {
    { input = "/home/alice/work tree/../项目/#notes", keep = false },
    { input = "C:\\Users\\alice\\..\\项目\\#notes", keep = false },
    { input = "folder/", keep = true },
  } ---@type { input: string, keep: boolean }[]

  for _, case in ipairs(cases) do
    local slash_path = native.path.normalize(case.input, case.keep, "/") ---@type string
    local expected = native.path.normalize(slash_path, case.keep, native.path.SEP) ---@type string
    t.assert_eq(expected, path.to_os(case.input, case.keep), "to_os " .. case.input)
  end

  t.assert_eq(
    native.path.normalize("folder/", true, native.path.SEP),
    path.to_os("folder/"),
    "to_os inferred trailing slash"
  )

  for _, input in ipairs({ "", false }) do
    t.assert_eq("", path.to_os(input), "to_os empty or non-string")
  end

  for _, input in ipairs({ "diffview://null", "git+ssh://example/repo" }) do
    t.assert_eq(input, path.to_os(input), "to_os URI-like")
  end
end)

t:test("join and resolve match generic slash operations", function()
  local cases = {
    { from = "/workspace", to = "src/main.lua" },
    { from = "/workspace/src", to = "../test/main.lua" },
    { from = "C:\\workspace", to = "src\\main.lua" },
    { from = "//server/share", to = "folder/file.lua" },
    { from = "/项目/源代码", to = "../测试/#fixture.lua" },
  } ---@type { from: string, to: string }[]

  for _, case in ipairs(cases) do
    local joined = native.path.join(case.from, case.to, true, "/") ---@type string
    local resolved = native.path.resolve(case.from, case.to, true, "/") ---@type string
    t.assert_eq(joined, path.join(case.from, case.to), "join " .. case.from .. " -> " .. case.to)
    t.assert_eq(resolved, path.resolve(case.from, case.to), "resolve " .. case.from .. " -> " .. case.to)
  end
end)

t:test("dirname matches generic slash operation", function()
  for _, case in ipairs(UNARY_CASES) do
    local expected = native.path.dirname(case.input, false, "/") ---@type string
    t.assert_eq(expected, path.dirname(case.input), "dirname " .. case.input)
  end
end)

t:test("relative keeps generic slash behavior", function()
  local cases = {
    { from = "/workspace/src", to = "/workspace/test/main.lua" },
    { from = "C:\\workspace\\src", to = "C:\\workspace\\test\\main.lua" },
    { from = "/项目/源代码", to = "/项目/测试/#fixture.lua" },
  } ---@type { from: string, to: string }[]

  for _, case in ipairs(cases) do
    local expected = native.path.relative(case.from, case.to, false, "/") ---@type string
    t.assert_eq(expected, path.relative(case.from, case.to), "relative " .. case.from .. " -> " .. case.to)
  end
end)

t:run()
