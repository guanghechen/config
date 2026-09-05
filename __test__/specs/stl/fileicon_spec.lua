--- Run with: nvim -l __test__/run.lua __test__/specs/stl/fileicon_spec.lua
---@diagnostic disable: undefined-global
--- Test for stl.fileicon

local bootstrap = require("__test__.support.bootstrap")
local harness = require("__test__.support.harness")

local t = harness.new("stl.fileicon")

local Filetype = require("stl.filetype")
bootstrap.with_runtime(t, {
  stl = {
    filetype = Filetype,
  },
  yoz = {
    path = {
      basename = function(filepath)
        return filepath
      end,
    },
  },
})

local Fileicon = require("stl.fileicon")

t:test("get_file_icon: spec and test suffixes use test icons", function()
  local cases = {
    { filename = "example.spec.js", filetype = "javascript", hl = "MiniIconsYellow" },
    { filename = "example.spec.cjs", filetype = "javascript", hl = "MiniIconsYellow" },
    { filename = "example.spec.mjs", filetype = "javascript", hl = "MiniIconsYellow" },
    { filename = "example.spec.ts", filetype = "typescript", hl = "MiniIconsBlue" },
    { filename = "example.spec.cts", filetype = "typescript", hl = "MiniIconsBlue" },
    { filename = "example.spec.mts", filetype = "typescript", hl = "MiniIconsBlue" },
    { filename = "example.spec.tsx", filetype = "typescriptreact", hl = "MiniIconsBlue" },
    { filename = "example.test.js", filetype = "javascript", hl = "MiniIconsYellow" },
    { filename = "example.test.cjs", filetype = "javascript", hl = "MiniIconsYellow" },
    { filename = "example.test.mjs", filetype = "javascript", hl = "MiniIconsYellow" },
    { filename = "example.test.ts", filetype = "typescript", hl = "MiniIconsBlue" },
    { filename = "example.test.cts", filetype = "typescript", hl = "MiniIconsBlue" },
    { filename = "example.test.mts", filetype = "typescript", hl = "MiniIconsBlue" },
    { filename = "example.test.tsx", filetype = "typescriptreact", hl = "MiniIconsBlue" },
  }

  for _, case in ipairs(cases) do
    local glyph, hl, is_default = Fileicon.get_file_icon(case.filename, case.filetype) ---@type string, string, boolean
    t.assert_eq("󰙨", glyph, case.filename .. " glyph")
    t.assert_eq(case.hl, hl, case.filename .. " highlight")
    t.assert_false(is_default, case.filename .. " should not be a fallback")
  end
end)

t:test("get_file_icon: test marker must be a complete preceding segment", function()
  local cases = {
    { filename = "example.cjs", filetype = "javascript" },
    { filename = "example.cts", filetype = "typescript" },
    { filename = "example.mjs", filetype = "javascript" },
    { filename = "example.contest.mjs", filetype = "javascript" },
    { filename = "test.mjs", filetype = "javascript" },
  }

  for _, case in ipairs(cases) do
    local expected_glyph, expected_hl = Fileicon.get_filetype_icon(case.filetype) ---@type string, string
    local glyph, hl = Fileicon.get_file_icon(case.filename, case.filetype) ---@type string, string
    t.assert_eq(expected_glyph, glyph, case.filename .. " glyph")
    t.assert_eq(expected_hl, hl, case.filename .. " highlight")
  end
end)

t:test("get_file_icon: empty filetype skips automatic detection", function()
  local detect_calls = 0 ---@type integer
  t:patch_table(stl.filetype, "detect", function()
    detect_calls = detect_calls + 1
    return "lua"
  end)

  local filename = "__fileicon_detection_probe__" ---@type string
  Fileicon.get_file_icon(filename, "")
  t.assert_eq(0, detect_calls, "explicit empty filetype")

  Fileicon.get_file_icon(filename)
  t.assert_eq(1, detect_calls, "missing filetype should use automatic detection")
end)

t:run()
