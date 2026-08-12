---@diagnostic disable: undefined-global
--- Test for the Lua-facing yoz path CWD contract
--- Run with: nvim -l lua/__test__/yoz/path_cwd.lua

local harness = require("__test__.harness")
local native = require("yoz")

local t = harness.new("yoz.path_cwd")

---@param input                         string
---@param label                         string
local function assert_synced(input, label)
  local dirpath = input .. "/" ---@type string
  local expected_path = native.path.normalize(dirpath, true, native.path.SEP) ---@type string
  local expected_canonical = native.canonical_path.normalize(dirpath, true) ---@type string

  t.assert_eq(expected_path, native.path.get_cwd(), label .. " generic CWD")
  t.assert_eq(expected_canonical, native.canonical_path.get_cwd(), label .. " canonical CWD")
end

t:test("path setter synchronizes both CWD representations", function()
  local input = native.path.SEP == "\\" and "C:\\workspace\\path-setter" or "/workspace/path-setter" ---@type string
  native.path.set_cwd(input)
  assert_synced(input, "path setter")
end)

t:test("canonical setter synchronizes both CWD representations", function()
  local input = native.path.SEP == "\\" and "C:\\workspace\\canonical-setter" or "/workspace/canonical-setter" ---@type string
  native.canonical_path.set_cwd(input)
  assert_synced(input, "canonical setter")
end)

t:run()
