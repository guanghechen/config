--- Run with: nvim -l __test__/run.lua __test__/specs/stl/os/path_spec.lua
---@diagnostic disable: undefined-global
--- Test for stl.os.path module

local bootstrap = require("__test__.support.bootstrap")
local harness = require("__test__.support.harness")
local native = require("yoz")

local t = harness.new("stl.os.path")

bootstrap.with_runtime(t, { yoz = native })

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

t:test("normalize matches generic slash normalization", function()
  for _, case in ipairs(UNARY_CASES) do
    local expected = native.path.normalize(case.input, case.keep, "/") ---@type string
    t.assert_eq(expected, path.normalize(case.input, case.keep), "normalize " .. case.input)
  end
end)

t:test("normalize preserves wrapper boundary behavior", function()
  for _, input in ipairs({ "folder/", "folder\\" }) do
    t.assert_eq("folder/", path.normalize(input), "normalize inferred trailing slash")
  end

  for _, input in ipairs({ "", false }) do
    t.assert_eq("", path.normalize(input), "normalize empty or non-string")
  end

  for _, input in ipairs({ "diffview://null", "git+ssh://example/repo" }) do
    t.assert_eq(input, path.normalize(input), "normalize URI-like")
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

t:test("relative matches generic slash behavior with synchronized CWD", function()
  local original_cwd = native.path.get_cwd() ---@type string
  local test_cwd = native.path.SEP == "\\" and "C:\\workspace" or "/workspace" ---@type string
  native.path.set_cwd(test_cwd)

  local ok, err = pcall(function()
    local cases = {
      { from = "", to = "" },
      { from = "", to = "src/main.lua" },
      { from = ".", to = "../shared/file.lua" },
      { from = "/workspace//src/./module", to = "/workspace/src/../test/main.lua" },
      { from = "/workspace/src", to = "/workspace/test/main.lua/" },
      { from = "C:\\workspace\\src", to = "C:\\workspace\\test\\main.lua" },
      { from = "C:\\workspace", to = "D:\\archive\\main.lua" },
      { from = "//server/share/src", to = "//server/share/test/main.lua" },
      { from = "/workspace/work tree", to = "/workspace/work tree/fixtures/main.lua" },
      { from = "/项目/源代码", to = "/项目/测试/#fixture.lua" },
    } ---@type { from: string, to: string }[]

    for _, case in ipairs(cases) do
      local expected = native.path.relative(case.from, case.to, false, "/") ---@type string
      t.assert_eq(expected, path.relative(case.from, case.to), "relative " .. case.from .. " -> " .. case.to)
    end
  end)

  native.path.set_cwd(original_cwd)
  if not ok then
    error(err, 0)
  end
end)

t:run()
